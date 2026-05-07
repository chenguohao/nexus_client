import 'package:desktop_drop/desktop_drop.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/pages/chat/add_contact_banner.dart';
import 'package:fluffychat/pages/chat/blocked_message_view.dart';
import 'package:fluffychat/pages/chat/blocked_user_banner.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/pages/chat/chat_audio_player_widget.dart';
import 'package:fluffychat/pages/chat/chat_background.dart';
import 'package:fluffychat/pages/chat/chat_event_list.dart';
import 'package:fluffychat/pages/chat/chat_loading_view.dart';
import 'package:fluffychat/pages/chat/chat_view_body_style.dart';
import 'package:fluffychat/pages/chat/chat_view_style.dart';
import 'package:fluffychat/pages/chat/disabled_chat_input_row.dart';
import 'package:fluffychat/pages/chat/events/edit_display.dart';
import 'package:fluffychat/pages/chat/events/message_content_mixin.dart';
import 'package:fluffychat/pages/chat/chat_pinned_events/pinned_events_view.dart';
import 'package:fluffychat/pages/chat/sticky_timestamp_widget.dart';
import 'package:fluffychat/pages/chat/tombstone_display.dart';
import 'package:fluffychat/pages/contacts_tab/widgets/add_contact/add_contact_dialog.dart';
import 'package:fluffychat/presentation/model/chat/view_event_list_ui_state.dart';
import 'package:fluffychat/resource/image_paths.dart';
import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:fluffychat/widgets/connection_status_header.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_emoji_mart/flutter_emoji_mart.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:linagora_design_flutter/linagora_design_flutter.dart';
import 'package:matrix/matrix.dart';
import 'chat_input_row.dart';

class ChatViewBody extends StatelessWidget with MessageContentMixin {
  final ChatController controller;

  const ChatViewBody(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (details) => controller.handleDragDone(details),
      onDragEntered: controller.onDragEntered,
      onDragUpdated: controller.onDragUpdated,
      onDragExited: controller.onDragExited,
      child: Container(
        color: const Color(0xFF131314),
        child: Stack(
          children: <Widget>[
            const ChatBackground(),
            if (Matrix.of(context).wallpaper != null)
              Image.file(
                Matrix.of(context).wallpaper!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (controller.room!.pinnedEventIds.isNotEmpty)
                      const SizedBox(
                        height: ChatViewStyle.pinnedMessageHintHeight,
                      ),
                    Expanded(
                      child: GestureDetector(
                        onTap: controller.clearSingleSelectedEvent,
                        child: Stack(
                          children: [
                            ValueListenableBuilder(
                              valueListenable:
                                  controller.openingChatViewStateNotifier,
                              builder: (context, viewState, __) {
                                if (viewState is ViewEventListLoading ||
                                    controller.timeline == null) {
                                  return const ChatLoadingView();
                                }

                                if (viewState is ViewEventListSuccess) {
                                  return ChatEventList(
                                    controller: controller,
                                  );
                                }

                                return const SizedBox.shrink();
                              },
                            ),
                            if (controller.room?.isAbandonedDMRoom == true)
                              const _RejectedInviteBanner(),
                          ],
                        ),
                      ),
                    ),
                    if (controller.room!.canSendDefaultMessages &&
                        controller.room!.membership == Membership.join) ...[
                      Center(
                        child: Container(
                          alignment: Alignment.center,
                          child: controller.room?.isAbandonedDMRoom == true
                              ? _AbandonedDMBar(controller: controller)
                              : _inputMessageWidget(context),
                        ),
                      ),
                    ] else ...[
                      const DisabledChatInputRow(),
                    ],
                  ],
                ),
                TombstoneDisplay(controller),
                Column(
                  children: [
                    ValueListenableBuilder(
                      valueListenable: controller.isBlockedUserNotifier,
                      builder: (context, isBlockedUser, _) {
                        if (!isBlockedUser) return const SizedBox.shrink();
                        return Column(
                          children: [
                            TwakeInkWell(
                              onTap: () async => controller.onTapUnblockUser(
                                context: context,
                                client: controller.client,
                                userID: controller.user?.id ?? '',
                                displayName: controller.user?.displayName ?? '',
                              ),
                              child: const BlockedUserBanner(),
                            ),
                            Divider(
                              height: ChatViewBodyStyle.dividerSize,
                              thickness: ChatViewBodyStyle.dividerSize,
                              color: Theme.of(context).dividerColor,
                            ),
                          ],
                        );
                      },
                    ),
                    ValueListenableBuilder(
                      valueListenable: getIt
                          .get<ContactsManager>()
                          .getContactsNotifier(),
                      builder: (context, state, child) {
                        final contactToAdd = controller.contactToAdd(state);
                        if (contactToAdd == null) {
                          return const SizedBox();
                        }

                        return AddContactBanner(
                          onTap: () => showAddContactDialog(
                            context,
                            displayName: contactToAdd.displayName,
                            matrixId: contactToAdd.id,
                          ),
                          show: controller.showAddContactBanner,
                        );
                      },
                    ),
                    PinnedEventsView(controller),
                    if (controller.room!.pinnedEventIds.isNotEmpty)
                      Divider(
                        height: ChatViewBodyStyle.dividerSize,
                        thickness: ChatViewBodyStyle.dividerSize,
                        color: Theme.of(context).dividerColor,
                      ),
                    ChatAudioPlayerWidget(matrix: controller.matrix),
                    SizedBox(
                      key: controller.stickyTimestampKey,
                      child: ValueListenableBuilder(
                        valueListenable: controller.stickyTimestampNotifier,
                        builder: (context, stickyTimestamp, child) {
                          return StickyTimestampWidget(
                            isStickyHeader: stickyTimestamp != null,
                            content: stickyTimestamp != null
                                ? stickyTimestamp.relativeTime(context)
                                : '',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ValueListenableBuilder(
              valueListenable: controller.draggingNotifier,
              builder: (context, dragging, _) {
                if (!dragging) return const SizedBox.shrink();
                return Container(
                  color: Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withOpacity(0.9),
                  alignment: Alignment.center,
                  child: const Icon(Icons.upload_outlined, size: 100),
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: controller.showEmojiPickerComposerNotifier,
              builder: (context, display, _) {
                if (!display) return const SizedBox.shrink();
                return Positioned(
                  bottom: 72,
                  right: 64,
                  child: MouseRegion(
                    onHover: (_) {
                      controller.showEmojiPickerComposerNotifier.value = true;
                    },
                    onExit: (_) async {
                      await Future.delayed(const Duration(seconds: 1));
                      controller.showEmojiPickerComposerNotifier.value = false;
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      width: ChatController.defaultMaxWidthReactionPicker,
                      height: ChatController.defaultMaxHeightReactionPicker,
                      decoration: BoxDecoration(
                        color: LinagoraRefColors.material().primary[100],
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x0000004D).withOpacity(0.15),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                            spreadRadius: 3,
                          ),
                          BoxShadow(
                            color: const Color(0x00000026).withOpacity(0.3),
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: EmojiPicker(
                        emojiData: Matrix.of(context).emojiData,
                        recentEmoji: controller.getRecentReactionsInteractor
                            .execute(),
                        configuration: EmojiPickerConfiguration(
                          showRecentTab: true,
                          emojiStyle: Theme.of(
                            context,
                          ).textTheme.headlineLarge!,
                          searchEmptyTextStyle: Theme.of(context)
                              .textTheme
                              .labelMedium!
                              .copyWith(
                                color:
                                    LinagoraRefColors.material().tertiary[30],
                              ),
                          searchEmptyWidget: SvgPicture.asset(
                            ImagePaths.icSearchEmojiEmpty,
                          ),
                          searchFocusNode: controller.searchEmojiFocusNode,
                        ),
                        itemBuilder: (context, emojiId, emoji, callback) {
                          return MouseRegion(
                            child: EmojiItem(
                              textStyle: Theme.of(
                                context,
                              ).textTheme.headlineLarge!,
                              onTap: () {
                                callback(emojiId, emoji);
                              },
                              emoji: emoji,
                            ),
                          );
                        },
                        onEmojiSelected: (emojiId, emoji) {
                          controller.typeEmoji(emoji);
                          controller.handleStoreRecentReactions(emoji);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputMessageWidget(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131314),
        border: Border(
          top: BorderSide(color: Color(0x0DFFFFFF)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ConnectionStatusHeader(),
          ValueListenableBuilder(
            valueListenable: controller.editEventNotifier,
            builder: (context, editEvent, _) {
              if (!controller.responsive.isMobile(context)) {
                return const SizedBox.shrink();
              }

              if (editEvent == null) return const SizedBox.shrink();
              return Padding(
                padding: ChatViewBodyStyle.inputBarPadding(context),
                child: EditDisplay(
                  editEventNotifier: controller.editEventNotifier,
                  onCloseEditAction: controller.cancelEditEventAction,
                  timeline: controller.timeline,
                ),
              );
            },
          ),
          ValueListenableBuilder(
            valueListenable: controller.isBlockedUserNotifier,
            builder: (context, isBlocked, child) {
              if (!isBlocked) {
                return child ?? const SizedBox();
              }

              return const BlockedMessageView();
            },
            child: Padding(
              padding: ChatViewBodyStyle.inputBarPadding(
                context,
              ).add(const EdgeInsetsGeometry.symmetric(vertical: 8)),
              child: ChatInputRow(controller),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Zeon-styled bottom bar for abandoned DM rooms ────────────────────────────

class _AbandonedDMBar extends StatelessWidget {
  final ChatController controller;
  const _AbandonedDMBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1B1C),
        border: Border(top: BorderSide(color: Color(0x33474747))),
      ),
      child: controller.isSupportChat
          ? const SizedBox.shrink()
          : _ZeonBarButton(
              label: l10n.leave.toUpperCase(),
              destructive: true,
              icon: Icons.logout,
              onTap: controller.leaveAbandonedDMAndGoHome,
            ),
    );
  }
}

// ── Rejected-invite overlay shown in the centre of the chat area ─────────────

class _RejectedInviteBanner extends StatelessWidget {
  const _RejectedInviteBanner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1B1C),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: const Color(0x4D474747)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.block,
                  color: Color(0xFFFFB4AB),
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  'INVITATION DECLINED',
                  style: const TextStyle(
                    color: Color(0xFFFFB4AB),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '对方拒绝了你的聊天请求。\n若仍想联系，请前往通讯录重新发起邀请。',
              style: TextStyle(
                color: Color(0xFF919191),
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ZeonBarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool destructive;
  final VoidCallback onTap;

  const _ZeonBarButton({
    required this.label,
    required this.icon,
    required this.destructive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? const Color(0xFFFFB4AB) : const Color(0xFFC6C6C6);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: destructive
                ? const Color(0x55FFB4AB)
                : const Color(0x33474747),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
