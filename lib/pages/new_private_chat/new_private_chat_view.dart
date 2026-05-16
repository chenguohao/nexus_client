import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/pages/contacts_tab/widgets/add_contact/add_contact_dialog.dart';
import 'package:fluffychat/pages/new_private_chat/new_private_chat.dart';
import 'package:fluffychat/pages/new_private_chat/new_private_chat_style.dart';
import 'package:fluffychat/pages/new_private_chat/widget/expansion_list.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/app_bars/searchable_app_bar.dart';
import 'package:fluffychat/widgets/app_bars/searchable_app_bar_style.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

class NewPrivateChatView extends StatelessWidget {
  final NewPrivateChatController controller;

  const NewPrivateChatView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZeonColors.background,
      appBar: PreferredSize(
        preferredSize: SearchableAppBarStyle.preferredSize(context),
        child: SearchableAppBar(
          title: L10n.of(context)!.newChat,
          searchModeNotifier: controller.isSearchModeNotifier,
          textEditingController: controller.textEditingController,
          openSearchBar: controller.openSearchBar,
          closeSearchBar: controller.closeSearchBar,
          focusNode: controller.searchFocusNode,
          foregroundColor: Colors.white,
          backgroundColor: ZeonColors.background,
          withBottomDivider: false,
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: PlatformInfos.isMobile
            ? ScrollViewKeyboardDismissBehavior.manual
            : ScrollViewKeyboardDismissBehavior.onDrag,
        padding: NewPrivateChatStyle.paddingBody,
        controller: controller.scrollController,
        child: Column(
          children: [
            ExpansionList(
              presentationContactsNotifier:
                  controller.presentationContactNotifier,
              goToNewGroupChat: () => controller.goToNewGroupChat(context),
              onContactTap: controller.onContactAction,
              onExternalContactTap: controller.onExternalContactAction,
              textEditingController: controller.textEditingController,
              goToCreateContact: () => showAddContactDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}
