import 'package:dartz/dartz.dart';
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/domain/app_state/direct_chat/create_direct_chat_failed.dart';
import 'package:fluffychat/domain/app_state/direct_chat/create_direct_chat_loading.dart';
import 'package:fluffychat/domain/app_state/direct_chat/create_direct_chat_success.dart';
import 'package:matrix/matrix.dart';

/// Manually implements direct chat creation instead of using client.startDirectChat()
/// to enable:
/// 1. Custom error recovery with automatic cleanup on failure
/// 2. Handling existing rooms with different membership states (invite/join/leave)
/// 3. Fine-grained control over encryption setup and room creation parameters
///
/// NOTE: This implementation should remain aligned with Matrix SDK's startDirectChat
/// behavior when possible to benefit from upstream fixes and improvements.
class CreateDirectChatInteractor {
  /// Creates or retrieves a direct chat room with the specified contact.
  ///
  /// Returns early if an existing room is found, otherwise creates a new room.
  /// Handles three existing room cases:
  /// 1. Already joined -> return existing room immediately
  /// 2. Invited -> accept invite, wait for sync, return room
  /// 3. Left/No room -> continue to create new room below
  Stream<Either<Failure, Success>> execute({
    required String contactMxId,
    required Client client,
    List<StateEvent>? initialState,
    bool enableEncryption = true,
    bool waitForSync = true,
    Map<String, dynamic>? powerLevelContentOverride,
    CreateRoomPreset? preset = CreateRoomPreset.trustedPrivateChat,
  }) async* {
    yield const Right(CreateDirectChatLoading());

    try {
      await client.getUserProfile(contactMxId);
    } on MatrixException catch (e) {
      if (e.error == MatrixError.M_FORBIDDEN) {
        yield const Left(NoPermissionForCreateChat());
        return;
      }
      // 其他 Matrix 错误（M_NOT_FOUND / 限流 / 偶发网络异常）这里只是预检，
      // 不能 yield Failure，否则会触发"创建失败"的 snackbar，但下面 createRoom
      // 仍会成功并 yield Success，导致用户先看到一闪而过的失败提示再看到成功。
      // 让 createRoom 成为唯一的真相源。
      Logs().w(
        'CreateDirectChatInteractor: getUserProfile($contactMxId) failed, '
        'continuing anyway',
        e,
      );
    }
    String? roomId;
    try {
      // Check if a direct chat already exists with this contact
      final directChatRoomId = client.getDirectChatFromUserId(contactMxId);
      if (directChatRoomId != null) {
        final room = client.getRoomById(directChatRoomId);
        if (room != null && !room.isAbandonedDMRoom) {
          // Case 1: Already joined - return existing room
          if (room.membership == Membership.join) {
            yield Right(CreateDirectChatSuccess(roomId: directChatRoomId));
            return;
          } else if (room.membership == Membership.invite) {
            // Case 2: Pending invite - accept and wait for sync
            await room.join();
            if (waitForSync) {
              await client.waitForRoomInSync(directChatRoomId, join: true);
            }
            final updatedRoom = client.getRoomById(directChatRoomId);
            if (updatedRoom != null &&
                updatedRoom.membership == Membership.join) {
              yield Right(CreateDirectChatSuccess(roomId: directChatRoomId));
              return;
            }
          } else if (room.membership == Membership.leave) {
            // Case 3: Left room - check if the other party is still in it.
            // If so, rejoin the existing room to avoid duplicate conversations.
            // If the room is empty (everyone left), create a new one instead.
            final otherMember = room
                .getParticipants()
                .where((u) => u.id != client.userID)
                .toList();
            final otherStillIn = otherMember.any(
              (u) => u.membership == Membership.join || u.membership == Membership.invite,
            );
            if (otherStillIn) {
              try {
                await room.join();
                if (waitForSync) {
                  await client.waitForRoomInSync(directChatRoomId, join: true);
                }
                final rejoinedRoom = client.getRoomById(directChatRoomId);
                if (rejoinedRoom != null &&
                    rejoinedRoom.membership == Membership.join) {
                  yield Right(CreateDirectChatSuccess(roomId: directChatRoomId));
                  return;
                }
              } catch (e) {
                Logs().w('Rejoin failed, will create a new room', e);
              }
            }
          }
          // Case 4: Rejoin failed or room is empty - create new room below
        }
      }

      // Add encryption state if enabled
      if (enableEncryption) {
        initialState ??= [];
        if (!initialState.any((s) => s.type == EventTypes.Encryption)) {
          initialState.add(
            StateEvent(
              content: {
                'algorithm': Client.supportedGroupEncryptionAlgorithms.first,
              },
              type: EventTypes.Encryption,
            ),
          );
        }
      }
      // Create new direct chat room with the contact invited at creation
      // time. The invite must be part of the createRoom payload so the
      // server associates is_direct with an actual two-party room from the
      // start. A separate inviteUser call after creation can cause some
      // homeservers to treat the room as a group rather than a DM.
      roomId = await client.createRoom(
        invite: [contactMxId],
        isDirect: true,
        preset: preset,
        initialState: initialState,
        powerLevelContentOverride: powerLevelContentOverride,
      );

      // Wait for room to sync before proceeding
      if (waitForSync) {
        await client.waitForRoomInSync(roomId, join: true);
        // Verify room exists after sync
        final room = client.getRoomById(roomId);
        if (room == null) {
          throw Exception('Room not synced after waitForRoomInSync');
        }
      }

      // Mark as direct chat so both sides recognise it as a DM.
      await Room(id: roomId, client: client).addToDirectChat(contactMxId);

      // `setAccountData` 只是把 m.direct 推到服务器，本地 client.accountData
      // 要等下一次 /sync 回包才会刷新。这中间有几百毫秒的"窗口期"——在这段
      // 时间里 room.isDirectChat 仍然是 false，ChatAppBarTitle 会按群聊展示
      // ("N MEMBERS" + 群头像兜底)，造成一次很扎眼的视觉跳变。
      // 这里直接乐观更新本地 accountData，让 isDirectChat 立刻为 true。
      _patchLocalDirectChats(client, contactMxId, roomId);

      yield Right(CreateDirectChatSuccess(roomId: roomId));
    } catch (e, s) {
      Logs().e('CreateDirectChatInteractor', e, s);
      if (roomId != null) {
        try {
          await client.leaveRoom(roomId);
          await client.forgetRoom(roomId);
        } catch (e) {
          Logs().e('CreateDirectChatInteractor: Failed to clean up room', e);
        }
      }
      yield Left(CreateDirectChatFailed(exception: e));
    }
  }

  /// 在 [Client.accountData] 的 `m.direct` 上乐观追加 (userId -> roomId)，
  /// 让 [Room.isDirectChat] 这种依赖 m.direct 的读路径立刻看到 DM 标记，
  /// 不必等待下一次 /sync 回包。
  void _patchLocalDirectChats(Client client, String userId, String roomId) {
    final raw = client.accountData['m.direct']?.content;
    final patched = <String, Object?>{
      if (raw != null) ...raw,
    };
    final existing = patched[userId];
    final dmRooms = <String>[
      if (existing is List) ...existing.whereType<String>(),
    ];
    if (dmRooms.contains(roomId)) return;
    dmRooms.add(roomId);
    patched[userId] = dmRooms;
    client.accountData['m.direct'] = BasicEvent(
      type: 'm.direct',
      content: patched,
    );
  }
}
