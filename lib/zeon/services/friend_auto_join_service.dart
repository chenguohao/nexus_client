import 'dart:async';

import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:matrix/matrix.dart';

/// 注册 sync listener，对"已 accepted 好友主动拉入的群邀请"自动 join。
///
/// 规则：
///   - 只处理 `Membership.invite` 的 room；
///   - 跳过 DM（`room.isDirectChat`）：DM 邀请仍走 chat_invitation_body 流程；
///   - 邀请人必须是当前用户已 accepted 的好友（[ContactsManager.isAcceptedFriend]）；
///   - 同一房间在一次会话里最多尝试一次 auto-join。
class FriendAutoJoinService {
  FriendAutoJoinService._();
  static final FriendAutoJoinService instance = FriendAutoJoinService._();

  Client? _client;
  StreamSubscription<SyncUpdate>? _sub;
  final Set<String> _attempted = <String>{};

  /// 登录完成后调用一次。重复传入同一个 client 直接 no-op。
  void start(Client client) {
    if (_client == client && _sub != null) return;
    stop();
    _client = client;
    _sub = client.onSync.stream.listen((_) => _processInvites(client));
    // 启动时立即扫一次，覆盖 listener 注册之前的旧 invite。
    _processInvites(client);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _client = null;
    _attempted.clear();
  }

  void _processInvites(Client client) {
    final manager = getIt.get<ContactsManager>();
    final selfId = client.userID;
    if (selfId == null) return;

    for (final room in client.rooms) {
      if (room.membership != Membership.invite) continue;
      if (room.isDirectChat) continue;
      if (_attempted.contains(room.id)) continue;

      final inviter = _inviterMxid(room, selfId);
      if (inviter == null) continue;
      if (!manager.isAcceptedFriend(inviter)) continue;

      _attempted.add(room.id);
      _autoJoin(room);
    }
  }

  /// 邀请人 = 自己那条 m.room.member 事件的 senderId。
  String? _inviterMxid(Room room, String selfId) {
    final memberState = room.getState(EventTypes.RoomMember, selfId);
    return memberState?.senderId;
  }

  Future<void> _autoJoin(Room room) async {
    try {
      Logs().i('[FriendAutoJoin] auto-joining room ${room.id}');
      await room.join();
    } catch (e, s) {
      // 失败回退 attempted 标记，下个 sync 还能再试。
      _attempted.remove(room.id);
      Logs().w('[FriendAutoJoin] join failed for ${room.id}', e, s);
    }
  }
}
