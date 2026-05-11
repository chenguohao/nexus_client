import 'package:fluffychat/domain/model/room/room_extension.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:fluffychat/pages/chat_details/chat_details.dart';
import 'package:fluffychat/pages/chat_details/chat_details_app_bar.dart';
import 'package:fluffychat/pages/chat_details/chat_details_view_style.dart';
import 'package:fluffychat/utils/dialog/twake_dialog.dart';
import 'package:fluffychat/utils/twake_snackbar.dart';
import 'package:fluffychat/widgets/app_bars/twake_app_bar.dart';
import 'package:fluffychat/widgets/twake_components/twake_icon_button.dart';
import 'package:flutter/material.dart';
class ChatDetailsView extends StatelessWidget {
  final ChatDetailsController controller;

  const ChatDetailsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    if (controller.room == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF131314),
        appBar: AppBar(
          backgroundColor: const Color(0xFF131314),
          title: Text(
            L10n.of(context)!.oopsSomethingWentWrong,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: Center(
          child: Text(
            L10n.of(context)!.youAreNoLongerParticipatingInThisChat,
            style: const TextStyle(color: Color(0xFF919191)),
          ),
        ),
      );
    }
    return StreamBuilder(
      stream: controller.room?.onUpdate.stream,
      builder: (context, _) {
        return Scaffold(
          bottomNavigationBar: ListenableBuilder(
            listenable: controller.removeUsersChangeNotifier,
            builder: (context, _) {
              if (!controller
                  .removeUsersChangeNotifier
                  .haveSelectedUsersNotifier
                  .value) {
                return const SizedBox.shrink();
              }
              return Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0x1F474747)),
                  ),
                  color: Color(0xFF1C1B1C),
                ),
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 12 + MediaQuery.of(context).padding.bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _CancelSelectionButton(controller: controller),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RemoveMembersButton(controller: controller),
                    ),
                  ],
                ),
              );
            },
          ),
          backgroundColor: const Color(0xFF131314),
          appBar: TwakeAppBar(
            title: L10n.of(context)!.groupInfo,
            leading: TwakeIconButton(
              paddingAll: 8,
              splashColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              iconColor: Colors.white,
              onTap: controller.widget.closeRightColumn,
              icon: controller.widget.isInStack
                  ? Icons.arrow_back_ios
                  : Icons.close,
            ),
            enableLeftTitle: true,
            centerTitle: true,
            withDivider: false,
            actions: [
              if (controller.room?.canEditChatDetails == true)
                TwakeIconButton(
                  paddingAll: 8,
                  splashColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  iconColor: Colors.white,
                  onTap: controller.onTapEditButton,
                  icon: Icons.edit_outlined,
                )
              else
                TwakeIconButton(
                  paddingAll: 8,
                  splashColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  iconColor: Colors.white,
                  onTapDown: (details) =>
                      controller.onTapMoreButton(context, details),
                  icon: Icons.more_vert,
                ),
            ],
            context: context,
          ),
          body: NestedScrollView(
            physics: const ClampingScrollPhysics(),
            key: controller.nestedScrollViewState,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              final room = controller.room;
              if (room == null) return [];
              return [
                ChatDetailsAppBar(
                  room: room,
                  tabList: controller.tabList,
                  tabController: controller.tabController,
                  muteNotifier: controller.muteNotifier,
                  onToggleNotification: controller.onToggleNotification,
                  innerBoxIsScrolled: innerBoxIsScrolled,
                  onSearch: controller.onTapSearch,
                  onMessage: controller.onTapMessage,
                ),
              ];
            },
            body: ClipRRect(
              borderRadius: BorderRadius.all(
                Radius.circular(
                  ChatDetailViewStyle.chatDetailsPageViewWebBorderRadius,
                ),
              ),
              child: Container(
                width: ChatDetailViewStyle.chatDetailsPageViewWebWidth,
                padding: ChatDetailViewStyle.paddingTabBarView,
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: controller.tabController,
                  children: controller.sharedPages().map((pages) {
                    return pages.child;
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CancelSelectionButton extends StatelessWidget {
  const _CancelSelectionButton({required this.controller});

  final ChatDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => controller.removeUsersChangeNotifier.unselectAllUsers(),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2B),
          border: Border.all(color: const Color(0x33474747)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.close, size: 18.0, color: Color(0xFF919191)),
            const SizedBox(width: 8),
            Text(
              L10n.of(context)!.cancel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF919191),
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoveMembersButton extends StatelessWidget {
  const _RemoveMembersButton({required this.controller});

  final ChatDetailsController controller;

  Future<void> _confirmAndRemove(BuildContext context) async {
    final users = controller.removeUsersChangeNotifier.usersList.toList();
    if (users.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1C1B1C),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L10n.of(context)!.removeMember,
                style: const TextStyle(
                  color: Color(0xFFE5E2E3),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                users.length == 1
                    ? '确认将 ${users.first.calcDisplayname()} 移出群聊吗？'
                    : '确认将选中的 ${users.length} 位成员移出群聊吗？',
                style: const TextStyle(
                  color: Color(0xFF919191),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0x33474747)),
                          color: const Color(0xFF2A2A2B),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            color: Color(0xFF919191),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0x66FFB4AB),
                          ),
                          color: const Color(0xFF2A1A1A),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '确认移除',
                          style: TextStyle(
                            color: Color(0xFFFFB4AB),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final result = await TwakeDialog.showFutureLoadingDialogFullScreen(
      future: () => Future.wait(users.map((user) => user.ban())),
    );
    if (result.error != null) {
      TwakeSnackBar.show(context, result.error!.message);
    }
    await controller.onUpdateMembers();
    controller.removeUsersChangeNotifier.unselectAllUsers();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller.removeUsersChangeNotifier,
      builder: (context, _) {
        final hasSelected =
            controller.removeUsersChangeNotifier.usersList.isNotEmpty;
        return InkWell(
          onTap: hasSelected ? () => _confirmAndRemove(context) : null,
          child: Container(
            decoration: BoxDecoration(
              color: hasSelected
                  ? const Color(0xFF2A1A1A)
                  : const Color(0xFF1F1F1F),
              border: Border.fromBorderSide(
                BorderSide(
                  color: hasSelected
                      ? const Color(0x66FFB4AB)
                      : const Color(0x22474747),
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_remove_outlined,
                  size: 18.0,
                  color: hasSelected
                      ? const Color(0xFFFFB4AB)
                      : const Color(0xFF444444),
                ),
                const SizedBox(width: 8),
                Text(
                  L10n.of(context)!.removeMember,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: hasSelected
                        ? const Color(0xFFFFB4AB)
                        : const Color(0xFF444444),
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
