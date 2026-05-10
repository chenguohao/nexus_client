import 'package:fluffychat/config/default_power_level_member.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:fluffychat/pages/chat_details/assign_roles_member_picker/selected_user_notifier.dart';
import 'package:fluffychat/pages/chat_details/participant_list_item/participant_list_item.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class ChatDetailsMembersPage extends StatelessWidget {
  final ValueNotifier<List<User>?> displayMembersNotifier;
  final int actualMembersCount;
  final VoidCallback openDialogInvite;
  final VoidCallback requestMoreMembersAction;
  final VoidCallback? onUpdatedMembers;
  final SelectedUsersMapChangeNotifier selectedUsersMapChangeNotifier;
  final bool isMobileAndTablet;
  final void Function(User member)? onSelectMember;
  final void Function(User member)? onRemoveMember;
  final void Function(User member, {DefaultPowerLevelMember? role})?
  onChangeRole;
  final VoidCallback onAddMembers;

  const ChatDetailsMembersPage({
    super.key,
    required this.displayMembersNotifier,
    required this.actualMembersCount,
    required this.openDialogInvite,
    required this.requestMoreMembersAction,
    required this.isMobileAndTablet,
    required this.selectedUsersMapChangeNotifier,
    this.onUpdatedMembers,
    this.onSelectMember,
    this.onRemoveMember,
    this.onChangeRole,
    required this.onAddMembers,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ValueListenableBuilder(
      valueListenable: displayMembersNotifier,
      builder: (context, members, child) {
        members ??= [];
        final canRequestMoreMembers = members.length < actualMembersCount;
        return Column(
          children: [
            InkWell(
              onTap: onAddMembers,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0x1F474747)),
                  ),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.person_add_outlined,
                        color: Color(0xFFE5E2E3),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        L10n.of(context)!.addMembers,
                        style: textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFE5E2E3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: members.length + (canRequestMoreMembers ? 1 : 0),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemBuilder: (BuildContext context, int index) {
                  if (index < members!.length) {
                    return Column(
                      children: [
                        ListenableBuilder(
                          listenable: selectedUsersMapChangeNotifier,
                          builder: (context, child) {
                            return ParticipantListItem(
                              members![index],
                              onUpdatedMembers: onUpdatedMembers,
                              selectionMode: selectedUsersMapChangeNotifier
                                  .getSelectionModeForUser(members[index]),
                              onSelectMember: onSelectMember,
                              onRemoveMember: onRemoveMember,
                              onChangeRole: onChangeRole,
                            );
                          },
                        ),
                        if (index < members.length - 1)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0x1F474747),
                            indent: 60,
                          ),
                      ],
                    );
                  }
                  final haveMoreMembers = actualMembersCount > members.length;
                  if (!haveMoreMembers) return const SizedBox.shrink();
                  return InkWell(
                    onTap: requestMoreMembersAction,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.refresh,
                            color: Color(0xFF919191),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            L10n.of(context)!.loadCountMoreParticipants(
                              (actualMembersCount - members.length).toString(),
                            ),
                            style: textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF919191),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
