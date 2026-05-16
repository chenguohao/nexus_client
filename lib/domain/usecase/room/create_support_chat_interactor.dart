import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/data/network/media/media_api.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/app_state/room/create_support_chat_state.dart';
import 'package:fluffychat/event/twake_event_types.dart';
import 'package:fluffychat/presentation/mixins/wellknown_mixin.dart';
import 'package:fluffychat/resource/image_paths.dart';
import 'package:fluffychat/utils/power_level_manager.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';

/// Matrix SDK [Client.getWellknown] always uses `https://<mxid-domain>/.well-known/...`.
/// Local Dendrite often uses `server_name: localhost` while the client connects to
/// `http://127.0.0.1:8008`, so discovery hits `https://localhost` (nothing listening).
/// Dendrite still serves the same JSON at the client base URL; fetch it on failure.
Future<DiscoveryInformation> _discoveryForSupportChat(Client client) async {
  try {
    return await client.getWellknown();
  } catch (e, s) {
    Logs().w(
      'CreateSupportChatInteractor: getWellknown failed, trying homeserver URL',
      e,
      s,
    );
    final hs = client.homeserver;
    if (hs == null) rethrow;
    final uri = hs.replace(path: '/.well-known/matrix/client');
    final response = await client.httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Well-known via homeserver failed: HTTP ${response.statusCode} ($uri)',
      );
    }
    return DiscoveryInformation.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>,
    );
  }
}

class CreateSupportChatInteractor {
  const CreateSupportChatInteractor();

  Stream<Either<Failure, Success>> execute(Client client) async* {
    yield Right(CreatingSupportChat());

    const type = TwakeEventTypes.supportChatCreatedEventType;
    const accountDataKey = 'createdSupportChat';
    String? roomId;
    String? userId;
    try {
      final discovery = await _discoveryForSupportChat(client);
      final supportChatTwakeId =
          (discovery.additionalProperties[WellKnownMixin.twakeChatKey]
              as Map?)?[WellKnownMixin.supportContact];
      if (supportChatTwakeId is! String || supportChatTwakeId.trim().isEmpty) {
        throw Exception('No support contact found in well-known');
      }

      userId = client.userID;
      if (userId == null) {
        throw Exception('No user id found');
      }

      Map<String, dynamic> supportRoom = {};
      try {
        supportRoom = await client.getAccountData(userId, type);
      } catch (e) {
        Logs().e(
          'CreateSupportChatInteractor: No support room found in account data',
        );
      }
      roomId = supportRoom[accountDataKey] as String?;
      Room? room = roomId != null ? client.getRoomById(roomId) : null;
      if (room != null) {
        yield Right(SupportChatExisted(roomId: roomId!));
        return;
      }

      final avatarMatrixFile = MatrixFile.fromMimeType(
        name: 'logo.png',
        mimeType: 'image/png',
        bytes: (await rootBundle.load(
          ImagePaths.supportAvatarPng,
        )).buffer.asUint8List(),
      );
      final avatarUrl = (await getIt.get<MediaAPI>().uploadFileWeb(
        file: avatarMatrixFile,
      )).contentUri;

      final powerLevelManager = getIt.get<PowerLevelManager>();
      roomId = await client.createGroupChat(
        groupName: 'Zeon Support',
        preset: CreateRoomPreset.trustedPrivateChat,
        enableEncryption: false,
        initialState: [
          if (avatarUrl != null)
            StateEvent(
              type: EventTypes.RoomAvatar,
              content: {'url': avatarUrl},
              stateKey: '',
            ),
        ],
        powerLevelContentOverride: {
          'events': powerLevelManager.getDefaultPowerLevelEventForMember(),
          'invite': powerLevelManager.getAdminPowerLevel(),
          'kick': powerLevelManager.getAdminPowerLevel(),
        },
      );
      room = client.getRoomById(roomId);
      if (room == null) {
        throw Exception('Failed to create support chat');
      }

      await room.invite(supportChatTwakeId);
      await Future.wait([
        room.setPower(
          supportChatTwakeId,
          powerLevelManager.getAdminPowerLevel(),
        ),
        room.setFavourite(true),
        client.setAccountData(userId, type, {accountDataKey: roomId}),
      ]);
      await room.setPower(userId, powerLevelManager.getUserPowerLevel());

      yield Right(SupportChatCreated(roomId: roomId));
    } catch (e) {
      Logs().e('CreateSupportChatInteractor::execute(): Exception', e);
      try {
        await Future.wait([
          if (roomId != null) client.leaveRoom(roomId),
          if (userId != null)
            client.setAccountData(userId, type, {accountDataKey: null}),
        ]);
      } catch (_) {}
      yield Left(CreateSupportChatFailed(exception: e));
    }
  }
}
