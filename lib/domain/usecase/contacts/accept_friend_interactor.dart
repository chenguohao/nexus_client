import 'package:collection/collection.dart';
import 'package:fluffychat/data/network/contact/friend_request_api.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/model/contact/friend_status.dart';
import 'package:fluffychat/domain/repository/contact/address_book_repository.dart';

/// 接受对方发来的好友请求。
class AcceptFriendInteractor {
  final FriendRequestApi _api = getIt.get<FriendRequestApi>();

  final AddressBookRepository _repo = getIt.get<AddressBookRepository>();

  Future<void> execute({required String contactId}) async {
    await _api.acceptFriend(contactId);
  }

  /// 先从服务器拉通讯录，再按邀请人 MXID 匹配 `pending_incoming` 并调用 accept。
  ///
  /// 若用户从未打开过通讯录，本地 [ContactsManager] 可能没有待处理记录，
  /// 此时仍会 `room.join()` 成功但不会调 accept，双方通讯录会一直停在待确认。
  Future<void> acceptPendingIncomingIfExists(String inviterMxid) async {
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
    await _api.acceptFriend(id);
  }
}
