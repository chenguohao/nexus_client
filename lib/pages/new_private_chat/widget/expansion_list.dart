import 'package:dartz/dartz.dart';
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/app_state/contact/get_contacts_state.dart';
import 'package:fluffychat/domain/model/contact/friend_status.dart';
import 'package:fluffychat/presentation/extensions/value_notifier_custom.dart';
import 'package:fluffychat/presentation/model/contact/get_presentation_contacts_empty.dart';
import 'package:fluffychat/presentation/model/contact/get_presentation_contacts_failure.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact_success.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/responsive/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:fluffychat/pages/new_private_chat/widget/expansion_contact_list_tile.dart';
import 'package:fluffychat/pages/new_private_chat/widget/no_contacts_found.dart';

class ExpansionList extends StatelessWidget {
  final ValueNotifierCustom<Either<Failure, Success>>
  presentationContactsNotifier;
  final Function() goToNewGroupChat;
  final Function(BuildContext context, PresentationContact contact)
  onExternalContactTap;
  final Function(BuildContext context, PresentationContact contact)
  onContactTap;
  final TextEditingController textEditingController;
  final VoidCallback? goToCreateContact;

  const ExpansionList({
    super.key,
    required this.presentationContactsNotifier,
    required this.goToNewGroupChat,
    required this.onExternalContactTap,
    required this.onContactTap,
    required this.textEditingController,
    this.goToCreateContact,
  });

  @override
  Widget build(BuildContext context) {
    final topButtons = _buildResponsiveButtons(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...topButtons,
        if (topButtons.isNotEmpty)
          const Divider(height: 1, color: Color(0x1F474747)),
        if (topButtons.isNotEmpty) const SizedBox(height: 4),
        _sliverContactsList(),
      ],
    );
  }

  Widget _sliverContactsList() {
    return ValueListenableBuilder(
      valueListenable: presentationContactsNotifier,
      builder: (context, state, child) {
        return state.fold(
          (failure) {
            final textControllerIsEmpty = textEditingController.text.isEmpty;
            if (failure is GetPresentationContactsFailure ||
                failure is GetPresentationContactsEmpty) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  NoContactsFound(
                    keyword: textControllerIsEmpty
                        ? null
                        : textEditingController.text,
                  ),
                ],
              );
            }
            return child!;
          },
          (success) {
            if (success is ContactsLoading) {
              return const SizedBox.shrink();
            }

            if (success is PresentationExternalContactSuccess) {
              return ExpansionContactListTile(
                contact: success.contact,
                highlightKeyword: textEditingController.text,
                onContactTap: () => onContactTap(context, success.contact),
              );
            }

            if (success is PresentationContactsSuccess) {
              final contacts = success.contacts
                  .where((c) => c.friendStatus == FriendStatus.accepted)
                  .toList();
              if (contacts.isEmpty && textEditingController.text.isNotEmpty) {
                return NoContactsFound(
                  keyword: textEditingController.text.isEmpty
                      ? null
                      : textEditingController.text,
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  if (contacts[index].matrixId != null &&
                      contacts[index].matrixId!.isNotEmpty) {
                    return ExpansionContactListTile(
                      contact: contacts[index],
                      highlightKeyword: textEditingController.text,
                      onContactTap: () =>
                          onContactTap(context, contacts[index]),
                    );
                  }
                  return child!;
                },
              );
            }

            return child!;
          },
        );
      },
      child: const SizedBox(),
    );
  }

  List<Widget> _buildResponsiveButtons(BuildContext context) {
    if (!getIt.get<ResponsiveUtils>().isSingleColumnLayout(context)) return [];

    return [
      _NewGroupButton(onPressed: goToNewGroupChat),
      if (PlatformInfos.isMobile)
        _CreateContactButton(onPressed: goToCreateContact),
    ];
  }
}

class _IconTextTileButton extends StatelessWidget {
  const _IconTextTileButton({
    required this.onPressed,
    required this.iconData,
    required this.text,
  });

  final Function()? onPressed;
  final IconData iconData;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.zero,
        splashColor: const Color(0x1AFFFFFF),
        highlightColor: const Color(0x0DFFFFFF),
        child: Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: SizedBox(
            height: 52.0,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 14.0),
                  child: Icon(iconData, color: ZeonColors.onSurface, size: 22),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: ZeonColors.onSurface,
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewGroupButton extends StatelessWidget {
  final Function() onPressed;

  const _NewGroupButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _IconTextTileButton(
      onPressed: onPressed,
      iconData: Icons.supervisor_account_outlined,
      text: L10n.of(context)!.newGroupChat,
    );
  }
}

class _CreateContactButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _CreateContactButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _IconTextTileButton(
      onPressed: onPressed,
      iconData: Icons.person_add_outlined,
      text: L10n.of(context)!.createNewContact,
    );
  }
}
