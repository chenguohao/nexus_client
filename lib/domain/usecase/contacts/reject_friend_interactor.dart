import 'package:collection/collection.dart';
import 'package:fluffychat/data/network/contact/friend_request_api.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/model/contact/friend_status.dart';
import 'package:fluffychat/domain/repository/contact/address_book_repository.dart';

/// 拒绝对方发来的好友请求。
///
/// 服务端语义：把对方端的记录改为 rejected（保留作历史），
/// 当前端的 pending_incoming 记录直接删除，不留痕迹。
class RejectFriendInteractor {
  final FriendRequestApi _api = getIt.get<FriendRequestApi>();

  final AddressBookRepository _repo = getIt.get<AddressBookRepository>();

  Future<void> execute({required String contactId}) async {
    await _api.rejectFriend(contactId);
  }

  /// 同上：先 GET 通讯录再按邀请人 MXID + pending_incoming 查找并 reject。
  Future<void> rejectPendingIncomingIfExists(String inviterMxid) async {
    final resp = await _repo.getAddressBook();
    final books = resp.addressBooks ?? [];
    final match = books.firstWhereOrNull(
      (b) =>
          b.mxid == inviterMxid &&
          FriendStatus.fromString(b.status) ==
              FriendStatus.pendingIncoming,
    );
    final id = match?.id;
    if (id == null || id.isEmpty) return;
    await _api.rejectFriend(id);
  }
}
