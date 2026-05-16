import 'package:fluffychat/domain/app_state/contact/get_contacts_state.dart';
import 'package:fluffychat/domain/model/contact/friend_status.dart';
import 'package:fluffychat/pages/contacts_tab/empty_contacts_body.dart';
import 'package:fluffychat/pages/new_group/contacts_selection.dart';
import 'package:fluffychat/pages/new_group/contacts_selection_view_style.dart';
import 'package:fluffychat/pages/new_group/widget/contact_item.dart';
import 'package:fluffychat/pages/new_group/widget/contacts_selection_list_style.dart';
import 'package:fluffychat/pages/new_group/widget/selected_participants_list.dart';
import 'package:fluffychat/pages/new_private_chat/widget/no_contacts_found.dart';
import 'package:fluffychat/presentation/model/contact/get_presentation_contacts_empty.dart';
import 'package:fluffychat/presentation/model/contact/get_presentation_contacts_failure.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact_success.dart';
import 'package:fluffychat/presentation/model/search/presentation_search.dart';
import 'package:fluffychat/widgets/app_bars/searchable_app_bar.dart';
import 'package:fluffychat/widgets/sliver_expandable_list.dart';
import 'package:fluffychat/widgets/twake_components/twake_fab.dart';
import 'package:fluffychat/widgets/twake_components/twake_text_button.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class ContactsSelectionView extends StatelessWidget {
  final ContactsSelectionController controller;
  final bool bannedHighlight;
  final Room? room;

  const ContactsSelectionView(
    this.controller, {
    super.key,
    this.bannedHighlight = false,
    this.room,
  });

  @override
  Widget build(BuildContext context) {
    final child = Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: PreferredSize(
        preferredSize: controller.isFullScreen
            ? ContactsSelectionViewStyle.preferredSize(context)
            : ContactsSelectionViewStyle.maxPreferredSize(context),
        child: SearchableAppBar(
          toolbarHeight: ContactsSelectionViewStyle.maxToolbarHeight(context),
          focusNode: controller.searchFocusNode,
          title: controller.getTitle(context),
          searchModeNotifier: controller.isSearchModeNotifier,
          hintText: controller.getHintText(context),
          textEditingController: controller.textEditingController,
          openSearchBar: controller.openSearchBar,
          closeSearchBar: controller.closeSearchBar,
          isFullScreen: controller.isFullScreen,
          backgroundColor: const Color(0xFF131314),
          foregroundColor: Colors.white,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: controller
                  .selectedContactsMapNotifier
                  .haveSelectedContactsNotifier,
              builder: (context, haveSelectedContact, child) {
                return child!;
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SelectedParticipantsList(
                      contactsSelectionController: controller,
                    ),
                  ),
                  _sliverRecentContacts(),
                  _sliverContactsList(),
                ],
              ),
            ),
          ),
          if (!controller.isFullScreen) _webActionButton(context),
        ],
      ),
      floatingActionButton: controller.isFullScreen
          ? AnimatedBuilder(
              animation: controller.selectedContactsMapNotifier,
              builder: (context, _) {
                final count =
                    controller.selectedContactsMapNotifier.contactsList.length;
                if (count < 1) return const SizedBox.shrink();
                final canProceed = count >= controller.minSelectedContactsToProceed;
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primaryContainer: canProceed
                          ? const Color(0xFF2A2A2B)
                          : const Color(0xFF1C1B1C),
                      onPrimaryContainer: canProceed
                          ? const Color(0xFFE5E2E3)
                          : const Color(0xFF636363),
                    ),
                  ),
                  child: TwakeFloatingActionButton(
                    icon: Icons.arrow_forward,
                    onTap: canProceed
                        ? () => controller.trySubmit(context)
                        : null,
                  ),
                );
              },
            )
          : null,
    );

    return ScaffoldMessenger(child: child);
  }

  Widget _sliverRecentContacts() {
    return ValueListenableBuilder(
      valueListenable: controller.presentationContactNotifier,
      builder: (context, state, child) {
        return state.fold((failure) => child!, (success) {
          if (success is ContactsLoading) {
            return const SliverToBoxAdapter(child: SizedBox());
          }
          return child!;
        });
      },
      child: ValueListenableBuilder(
        valueListenable: controller.presentationRecentContactNotifier,
        builder: (context, recentContacts, child) {
          if (recentContacts.isEmpty) {
            return child!;
          }
          return SliverExpandableList(
            title: L10n.of(context)!.recent,
            itemCount: recentContacts.length,
            itemBuilder: (context, index) {
              final disabled = controller.disabledContactIds.contains(
                recentContacts[index].directChatMatrixID,
              );
              return ContactItem(
                disableBannedUser: bannedHighlight,
                room: room,
                contact: recentContacts[index].toPresentationContact(),
                selectedContactsMapNotifier:
                    controller.selectedContactsMapNotifier,
                onSelectedContact: controller.onSelectedContact,
                highlightKeyword: controller.textEditingController.text,
                disabled: disabled,
              );
            },
          );
        },
        child: const SliverToBoxAdapter(child: SizedBox()),
      ),
    );
  }

  Widget _sliverContactsList() {
    final recentContact =
        controller.presentationRecentContactNotifier.value.isEmpty;

    return ValueListenableBuilder(
      valueListenable: controller.presentationContactNotifier,
      builder: (context, state, child) {
        return state.fold(
          (failure) {
            final presentationRecentContact =
                controller.presentationRecentContactNotifier.value;
            if (presentationRecentContact.isNotEmpty) {
              return child!;
            }
            if (failure is GetPresentationContactsFailure ||
                failure is GetPresentationContactsEmpty) {
              final keyword = controller.textEditingController.text;
              if (keyword.isEmpty) {
                return const SliverToBoxAdapter(child: EmptyContactBody());
              } else {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: ContactsSelectionListStyle.notFoundPadding,
                    child: NoContactsFound(
                      keyword: controller.textEditingController.text.isEmpty
                          ? null
                          : controller.textEditingController.text,
                    ),
                  ),
                );
              }
            }
            return child!;
          },
          (success) {
            if (success is ContactsLoading) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }

            if (success is PresentationExternalContactSuccess &&
                recentContact) {
              if (controller
                  .presentationRecentContactNotifier
                  .value
                  .isNotEmpty) {
                return child!;
              }
              return SliverToBoxAdapter(
                child: ContactItem(
                  disableBannedUser: bannedHighlight,
                  room: room,
                  contact: success.contact,
                  selectedContactsMapNotifier:
                      controller.selectedContactsMapNotifier,
                  onSelectedContact: controller.onSelectedContact,
                  highlightKeyword: controller.textEditingController.text,
                  disabled: false,
                ),
              );
            }

            if (success is PresentationContactsSuccess) {
              // 拉群/邀请只能选 accepted 好友。pending/rejected 的人由
              // OutgoingRequestsPage 等专门入口管理。
              final contacts = success.contacts
                  .where((c) => c.friendStatus == FriendStatus.accepted)
                  .toList();
              if (contacts.isEmpty &&
                  controller.textEditingController.text.isNotEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: ContactsSelectionListStyle.notFoundPadding,
                    child: NoContactsFound(
                      keyword: controller.textEditingController.text,
                    ),
                  ),
                );
              }
              return SliverExpandableList(
                title: L10n.of(context)!.linagoraContactsCount(contacts.length),
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final disabled = controller.disabledContactIds.contains(
                    contacts[index].matrixId,
                  );
                  return ContactItem(
                    disableBannedUser: bannedHighlight,
                    room: room,
                    contact: contacts[index],
                    selectedContactsMapNotifier:
                        controller.selectedContactsMapNotifier,
                    onSelectedContact: controller.onSelectedContact,
                    highlightKeyword: controller.textEditingController.text,
                    disabled: disabled,
                    paddingTop: index == 0
                        ? ContactsSelectionListStyle.listPaddingTop
                        : 0,
                  );
                },
              );
            }

            return child!;
          },
        );
      },
      child: const SliverToBoxAdapter(child: SizedBox()),
    );
  }

  Widget _webActionButton(BuildContext context) {
    return Padding(
      padding: ContactsSelectionViewStyle.webActionsButtonPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TwakeTextButton(
            onTap: () => Navigator.of(context).pop(),
            message: L10n.of(context)!.cancel,
            borderHover: 0,
            margin: ContactsSelectionViewStyle.webActionsButtonMargin,
            buttonDecoration: BoxDecoration(
              color: const Color(0xFF2A2A2B),
              border: Border.all(color: const Color(0x33474747)),
            ),
            styleMessage: const TextStyle(
              color: Color(0xFF919191),
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(width: 8.0),
          AnimatedBuilder(
            animation: controller.selectedContactsMapNotifier,
            builder: (context, _) {
              final count =
                  controller.selectedContactsMapNotifier.contactsList.length;
              final canProceed =
                  count >= controller.minSelectedContactsToProceed;
              return TwakeTextButton(
                onTap: canProceed ? () => controller.trySubmit(context) : null,
                message: L10n.of(context)!.add,
                margin: ContactsSelectionViewStyle.webActionsButtonMargin,
                borderHover: 0,
                buttonDecoration: BoxDecoration(
                  color: canProceed
                      ? const Color(0xFF2A2A2B)
                      : const Color(0xFF1C1B1C),
                  border: Border.all(
                    color: canProceed
                        ? const Color(0x55E5E2E3)
                        : const Color(0x33474747),
                  ),
                ),
                styleMessage: TextStyle(
                  color: canProceed
                      ? const Color(0xFFE5E2E3)
                      : const Color(0xFF636363),
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
