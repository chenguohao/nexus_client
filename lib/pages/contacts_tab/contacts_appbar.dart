import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/pages/contacts_tab/contacts_appbar_style.dart';
import 'package:fluffychat/pages/contacts_tab/widgets/add_contact/add_contact_dialog.dart';
import 'package:fluffychat/pages/search/search_text_field.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/responsive/responsive_utils.dart';
import 'package:fluffychat/widgets/app_bars/twake_app_bar.dart';
import 'package:flutter/material.dart';

class ContactsAppBar extends StatelessWidget {
  final ValueNotifier<bool> isSearchModeNotifier;
  final FocusNode searchFocusNode;
  final TextEditingController textEditingController;
  final Function()? clearSearchBar;
  static ResponsiveUtils responsiveUtils = getIt.get<ResponsiveUtils>();

  const ContactsAppBar({
    super.key,
    required this.isSearchModeNotifier,
    required this.searchFocusNode,
    required this.textEditingController,
    this.clearSearchBar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TwakeAppBar(
          title: 'Contacts',
          context: context,
          backgroundColor: const Color(0xFF131314),
          actions: [
            Padding(
              padding: PlatformInfos.isMobile
                  ? EdgeInsets.zero
                  : const EdgeInsetsDirectional.only(end: 4),
              child: IconButton(
                onPressed: () {
                  showAddContactDialog(context);
                },
                icon: const Icon(
                  Icons.person_add_alt,
                  color: Colors.white,
                ),
                padding: PlatformInfos.isMobile
                    ? EdgeInsets.zero
                    : const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        ValueListenableBuilder<bool>(
          valueListenable: isSearchModeNotifier,
          builder: (context, isSearchMode, child) {
            return Container(
              color: const Color(0xFF131314),
              height: ContactsAppbarStyle.textFieldHeight,
              padding: ContactsAppbarStyle.searchFieldPadding,
              child: SearchTextField(
                textEditingController: textEditingController,
                autofocus: false,
                focusNode: searchFocusNode,
              ),
            );
          },
        ),
      ],
    );
  }
}
