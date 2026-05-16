import 'package:fluffychat/data/network/contact/friend_request_api.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/zeon/services/friend_request_history.dart';
import 'package:matrix/matrix.dart';

/// 发起好友请求的整套流程：
/// 1. 校验目标 mxid 在 Matrix 上存在；
/// 2. 创建（或复用）一个与对方的 DM 房间并 invite 对方，作为好友请求的载体；
/// 3. 调 zeon_server `/_twake/addressbook/request` 写入双方的 pending 记录；
/// 4. 把对方 mxid 写进本地 [FriendRequestHistoryStore]，二级页"已确认"分组用。
///
/// 任何一步失败都直接抛异常，让 UI 层显示错误（不做静默回滚——
/// 即便 DM 已建好但服务端写入失败，下一次重试覆盖即可）。
class RequestFriendInteractor {
  final FriendRequestApi _api = getIt.get<FriendRequestApi>();

  Future<void> execute({
    required Client matrixClient,
    required String mxid,
    String? displayName,
  }) async {
    // 1. 校验对方 Matrix 用户存在
    final profile = await matrixClient.getUserProfile(mxid);
    final remoteName = profile.displayname;

    // 2. DM 房间：已存在直接复用，否则创建
    final existing = matrixClient.getDirectChatFromUserId(mxid);
    final roomId = existing ?? await matrixClient.startDirectChat(mxid);

    // 3. 写服务端 pending 记录
    await _api.requestFriend(
      mxid: mxid,
      displayName: displayName ?? remoteName,
      roomId: roomId,
    );

    // 4. 写本地历史
    await FriendRequestHistoryStore.instance.add(mxid);
  }
}
