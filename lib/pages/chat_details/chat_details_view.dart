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
          floatingActionButton: ListenableBuilder(
            listenable: controller.removeUsersChangeNotifier,
            builder: (context, _) {
              if (!controller
                  .removeUsersChangeNotifier
                  .haveSelectedUsersNotifier
                  .value) {
                return const SizedBox();
              }
              return _RemoveMembersButton(controller: controller);
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

class _RemoveMembersButton extends StatelessWidget {
  const _RemoveMembersButton({required this.controller});

  final ChatDetailsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        final result = await TwakeDialog.showFutureLoadingDialogFullScreen(
          future: () => Future.wait(
            controller.removeUsersChangeNotifier.usersList.map(
              (user) => user.ban(),
            ),
          ),
        );
        if (result.error != null) {
          TwakeSnackBar.show(context, result.error!.message);
        }

        await controller.onUpdateMembers();
        controller.removeUsersChangeNotifier.unselectAllUsers();
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2A1A1A),
          border: Border.fromBorderSide(
            BorderSide(color: Color(0x66FFB4AB)),
          ),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 24, 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_remove_outlined,
              size: 18.0,
              color: Color(0xFFFFB4AB),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                L10n.of(context)!.removeMember,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFFFFB4AB),
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
