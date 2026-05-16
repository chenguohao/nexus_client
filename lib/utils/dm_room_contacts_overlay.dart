import 'package:collection/collection.dart';
import 'package:dartz/dartz.dart' show Either;
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/domain/app_state/contact/get_contacts_state.dart';
import 'package:fluffychat/presentation/extensions/contact/presentation_contact_extension.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact.dart';
import 'package:matrix/matrix.dart';

/// DM 会话在 Matrix Room 层有时暂时没有对方的 displayname / avatar（成员事件未同步完整），
/// 但 Tom 通讯录已有昵称。本工具复用 [ChatAppBarTitle] 的合并策略，供会话列表等与通讯录对齐。
class DmRoomContactsOverlay {
  static List<PresentationContact> _contactsFromState(
    Either<Failure, Success> getContactsState,
  ) {
    return getContactsState.fold(
      (failure) => <PresentationContact>[],
      (success) => success is GetContactsSuccess
          ? success.contacts
              .fold(
                <PresentationContact>{},
                (previous, contact) => {
                  ...previous,
                  ...contact.toPresentationContacts(),
                },
              )
              .toList()
          : <PresentationContact>[],
    );
  }

  /// 会话列表 / AppBar 等与通讯录一致的展示名（DM 优先通讯录昵称）。
  static String resolvedDisplayName(
    Room room,
    MatrixLocalizations matrixLocalizations,
    Either<Failure, Success> getContactsState,
  ) {
    final directChatMatrixId = room.directChatMatrixID;
    final localizedRoomName =
        room.getLocalizedDisplayname(matrixLocalizations);
    if (directChatMatrixId == null) {
      return localizedRoomName;
    }

    final currentContacts = _contactsFromState(getContactsState);
    final availableContact = currentContacts.firstWhereOrNull(
      (contact) => contact.matrixId == directChatMatrixId,
    );
    return availableContact?.displayName ?? localizedRoomName;
  }
}
