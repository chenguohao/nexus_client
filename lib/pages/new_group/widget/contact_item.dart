import 'package:fluffychat/domain/model/room/room_extension.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:fluffychat/pages/new_group/selected_contacts_map_change_notifier.dart';
import 'package:fluffychat/pages/new_group/widget/contacts_selection_list_style.dart';
import 'package:fluffychat/pages/new_private_chat/widget/expansion_contact_list_tile.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact.dart';
import 'package:fluffychat/utils/twake_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class ContactItem extends StatelessWidget {
  final PresentationContact contact;
  final SelectedContactsMapChangeNotifier selectedContactsMapNotifier;
  final VoidCallback? onSelectedContact;
  final bool disabled;
  final double paddingTop;
  final String highlightKeyword;
  final bool disableBannedUser;
  final Room? room;

  const ContactItem({
    super.key,
    required this.contact,
    required this.selectedContactsMapNotifier,
    this.onSelectedContact,
    this.highlightKeyword = '',
    this.disabled = false,
    this.paddingTop = 0,
    this.disableBannedUser = false,
    this.room,
  });

  bool canSelect(BuildContext context) {
    if (!disableBannedUser) return true;
    if (!room.canSelectToInvite(contact.matrixId)) {
      TwakeSnackBar.show(context, L10n.of(context)!.cannotInviteBannedMember);
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final contactNotifier = selectedContactsMapNotifier.getNotifierAtContact(
      contact,
    );
    return Stack(
      children: [
        InkWell(
          key: ValueKey(contact.matrixId ?? contact.hashCode),
          onTap: disabled
              ? null
              : () {
                  if (!canSelect(context)) return;
                  onSelectedContact?.call();
                  selectedContactsMapNotifier.onContactTileTap(
                    context,
                    contact,
                  );
                },
          borderRadius: ContactsSelectionListStyle.contactItemBorderRadius,
          child: Container(
            width: MediaQuery.of(context).size.width,
            margin: ContactsSelectionListStyle.contactItemPadding,
            padding: ContactsSelectionListStyle.checkBoxPadding(paddingTop),
            child: Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: contactNotifier,
                  builder: (context, isCurrentSelected, child) {
                    final isChecked = disabled || contactNotifier.value;
                    return Checkbox(
                      value: isChecked,
                      // disabled（已在群里）：灰底灰勾，明显勾选但不可操作
                      // 正常选中：白底黑勾
                      fillColor: WidgetStateProperty.resolveWith((states) {
                        if (disabled) return const Color(0xFF474747);
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return Colors.transparent;
                      }),
                      checkColor: disabled
                          ? const Color(0xFFAAAAAA)
                          : const Color(0xFF131314),
                      side: BorderSide(
                        color: disabled
                            ? const Color(0xFF474747)
                            : const Color(0xFF636363),
                        width: 2,
                      ),
                      onChanged: disabled
                          ? null
                          : (newValue) {
                              if (!canSelect(context)) return;
                              onSelectedContact?.call();
                              selectedContactsMapNotifier.onContactTileTap(
                                context,
                                contact,
                              );
                            },
                    );
                  },
                ),
                Expanded(
                  child: ExpansionContactListTile(
                    contact: contact,
                    highlightKeyword: highlightKeyword,
                    suppressInkWell: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (disableBannedUser && !room.canSelectToInvite(contact.matrixId))
          const Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: Color(0x44131314))),
          ),
      ],
    );
  }
}
