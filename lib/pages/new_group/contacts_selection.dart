import 'package:fluffychat/presentation/mixins/address_book_mixin.dart';
import 'package:fluffychat/presentation/mixins/contacts_view_controller_mixin.dart';
import 'package:fluffychat/presentation/mixins/invite_external_contact_mixin.dart';
import 'package:fluffychat/pages/new_group/contacts_selection_view.dart';
import 'package:fluffychat/pages/new_group/selected_contacts_map_change_notifier.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:matrix/matrix.dart';

abstract class ContactsSelectionController<T extends StatefulWidget>
    extends State<T>
    with
        InviteExternalContactMixin,
        ContactsViewControllerMixin,
        AddressBooksMixin,
        WidgetsBindingObserver {
  /// 新建群组选人页至少勾选的好友人数（不含当前用户；自己会在群内，
  /// 因此勾选 2 人即为三人成群）。
  static const int minSelectedContactsForNewGroupChat = 2;

  final selectedContactsMapNotifier = SelectedContactsMapChangeNotifier();

  /// 至少勾选多少人后可进入下一步。新建群组覆盖为 [minSelectedContactsForNewGroupChat]；
  /// 群内邀请成员等为 1。
  int get minSelectedContactsToProceed => 1;

  String getTitle(BuildContext context);

  String getHintText(BuildContext context);

  void onSubmit();

  List<String> get disabledContactIds => [];

  Iterable<PresentationContact> get contactsList =>
      selectedContactsMapNotifier.contactsList;

  bool get isFullScreen => true;

  Client get client => Matrix.of(context).client;

  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      WidgetsBinding.instance.addObserver(this);
      if (mounted) {
        listenAddressBookEvents(client);
        initialFetchContacts(
          context: context,
          client: client,
          matrixLocalizations: MatrixLocals(L10n.of(context)!),
        );
      }
    });
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disposeContactsMixin();
    selectedContactsMapNotifier.dispose();
    super.dispose();
  }

  void trySubmit(BuildContext context) {
    if (selectedContactsMapNotifier.contactsList.length <
        minSelectedContactsToProceed) {
      return;
    }
    onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    return ContactsSelectionView(this);
  }
}
