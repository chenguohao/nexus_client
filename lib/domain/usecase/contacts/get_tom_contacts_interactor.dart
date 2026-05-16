import 'package:dartz/dartz.dart';
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/app_state/contact/get_contacts_state.dart';
import 'package:fluffychat/domain/model/contact/friend_status.dart';
import 'package:fluffychat/domain/model/extensions/contact/address_book_extension.dart';
import 'package:fluffychat/domain/repository/contact/address_book_repository.dart';

class GetTomContactsInteractor {
  final AddressBookRepository addressBookRepository = getIt
      .get<AddressBookRepository>();

  GetTomContactsInteractor();

  Stream<Either<Failure, Success>> execute({bool emitLoading = true}) async* {
    try {
      if (emitLoading) {
        yield const Right(ContactsLoading());
      }
      final response = await addressBookRepository.getAddressBook();

      final addressBooks = response.addressBooks ?? [];
      final contacts = addressBooks.toContacts();

      // 顺路构建 mxid -> friendStatus 速查表，供 UI 状态判断使用。
      final friendStatusByMxid = <String, FriendStatus>{};
      for (final ab in addressBooks) {
        final mxid = ab.mxid;
        if (mxid == null || mxid.isEmpty) continue;
        friendStatusByMxid[mxid] = FriendStatus.fromString(ab.status);
      }

      if (contacts.isEmpty) {
        yield const Left(GetContactsIsEmpty());
      } else {
        yield Right(
          GetContactsSuccess(
            contacts: contacts,
            friendStatusByMxid: friendStatusByMxid,
          ),
        );
      }
    } catch (e) {
      yield Left(GetContactsFailure(keyword: '', exception: e));
    }
  }
}
