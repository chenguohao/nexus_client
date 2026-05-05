import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

/// "Soft Logout" — 与 Matrix SDK 默认 [Client.logout] 不同，本流程保留
/// 本地 Hive 数据库（包含 Megolm 群组会话密钥、房间状态、未发送队列等），
/// 仅做以下三件事：
///
/// 1. 调用 Matrix HTTP API `POST /_matrix/client/v3/logout` 让服务端废弃当前
///    access token（best-effort，失败不影响主流程）。
/// 2. 中止后台 sync 循环。
/// 3. 在 [Client.onLoginStateChanged] 上推送 [LoginState.loggedOut]，让 UI
///    层自然导航到 `/home`，复用既有的"登出"路径。
///
/// 这样设计是因为产品场景是「钱包私钥 = 账号身份 = 单设备」，登出更接近
/// 「锁屏 / 切账号占位」而不是「彻底从设备上抹除我的身份」。同账号再次登录
/// 时，[ZeonRecoverPage._loginMatrixClient] 会在 [Client.init] 之前调用
/// [ensureCleanForUser]，仅当登录的 Matrix UserID 与本地缓存不一致时才执行
/// 真正的 [Client.clear]。
///
/// > 注意：因为本地 Olm 帐户是 device-bound 的，重新登录后 server 视角下仍
/// > 是「同账号、新 device」。因此**对方在本次软登出之后**新发的 E2E 消息，
/// > 在本设备上仍会触发一次 key request 流程。但**软登出之前的历史消息**
/// > 全部可解密（这是修复目的）。
class ZeonSoftLogout {
  ZeonSoftLogout._();

  /// Best-effort 调用 server 的 logout 接口废弃 access token。
  /// 失败仅记录日志，不抛异常。
  static Future<void> _invalidateServerToken(Client client) async {
    final homeserver = client.homeserver;
    final token = client.accessToken;
    if (homeserver == null || token == null || token.isEmpty) {
      Logs().w(
        'ZeonSoftLogout: homeserver/token missing, skipping server-side '
        'invalidation',
      );
      return;
    }

    final uri = homeserver.replace(path: '/_matrix/client/v3/logout');
    try {
      final response = await http
          .post(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 5));
      Logs().i(
        'ZeonSoftLogout: server token invalidation returned '
        '${response.statusCode}',
      );
    } catch (e) {
      // 服务器宕机 / 网络故障都不影响本地登出。
      Logs().w('ZeonSoftLogout: server token invalidation failed (ignored): $e');
    }
  }

  /// 执行 soft logout。调用方在此之后应负责导航到登录页。
  static Future<void> execute(Client client) async {
    Logs().i(
      'ZeonSoftLogout: starting for userId=${client.userID} '
      'deviceId=${client.deviceID}',
    );

    try {
      await client.abortSync();
    } catch (e) {
      Logs().w('ZeonSoftLogout: abortSync failed (ignored): $e');
    }

    await _invalidateServerToken(client);

    // 主动推送 loggedOut 状态。MatrixState._listenLoginStateChanged 会感知
    // 此事件并导航到 /home。区别于 client.logout()，我们没有调用 clear()，
    // 所以 Hive 中的 Megolm session、房间历史、用户配置全部保留。
    client.onLoginStateChanged.add(LoginState.loggedOut);

    Logs().i('ZeonSoftLogout: done — local data preserved');
  }

  /// 在 Recovery 流程的 [Client.init] 之前调用：
  /// - 同账号 → 不动 Hive，让历史消息可继续解密。
  /// - 跨账号 → 清空，避免账号 A 的密钥被账号 B 误用。
  static Future<void> ensureCleanForUser(
    Client client,
    String newUserId,
  ) async {
    final previousUserId = client.userID;
    if (previousUserId == null || previousUserId == newUserId) {
      Logs().i(
        'ZeonSoftLogout: same user (${previousUserId ?? "<none>"}), keeping '
        'local store',
      );
      return;
    }

    Logs().i(
      'ZeonSoftLogout: account changed ($previousUserId → $newUserId), '
      'wiping local store before init()',
    );
    try {
      await client.clear();
    } catch (e) {
      Logs().e('ZeonSoftLogout: clear() failed', e);
      // 不 rethrow——init 阶段 ZeonMatrixClientDatabase.ensureOpenBeforeInit
      // 仍有兜底，会重建数据库。
    }
  }
}
