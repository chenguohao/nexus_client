import 'dart:async';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/pages/chat/typing_timer_wrapper.dart';
import 'package:fluffychat/presentation/mixins/chat_list_item_mixin.dart';
import 'package:fluffychat/pages/chat_list/chat_list_item_style.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/room_status_extension.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:matrix/matrix.dart';

class ChatListItemSubtitle extends StatelessWidget with ChatListItemMixin {
  final Room room;
  final Event? lastEvent;

  const ChatListItemSubtitle({super.key, required this.room, this.lastEvent});

  @override
  Widget build(BuildContext context) {
    final typingText = room.getLocalizedTypingText(L10n.of(context)!);
    final isGroup = !room.isDirectChat;
    final unreadBadgeSize = ChatListItemStyle.unreadBadgeSize(
      room.isUnreadOrInvited,
      room.hasNewMessages,
      room.notificationCount > 0,
    );
    final lastEvent = this.lastEvent ?? room.lastEvent;
    final isMediaEvent =
        lastEvent?.messageType == MessageTypes.Image ||
        lastEvent?.messageType == MessageTypes.Video;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _buildMainSubtitleContent(
            context,
            lastEvent,
            typingText,
            isGroup,
            isMediaEvent,
          ),
        ),
        const SizedBox(width: 8),
        FutureBuilder<String>(
          future:
              lastEvent?.calcLocalizedBody(
                MatrixLocals(L10n.of(context)!),
                hideReply: true,
                hideEdit: true,
                plaintextBody: true,
                removeMarkdown: true,
              ) ??
              Future.value(''),
          builder: (context, snapshot) {
            if (snapshot.data == '' ||
                snapshot.data == null ||
                lastEvent == null) {
              return const SizedBox.shrink();
            }
            final isMentioned = lastEvent.isMention == true;
            final myUserId = Matrix.of(context).client.userID;
            // 与会话内消息保持一致的 Telegram 约定：
            // - 无他人已读 → 单勾
            // - 有他人已读 → 双勾
            // 注意：Matrix SDK 的 event.receipts 会包含发送者本人的 m.read，
            // 必须过滤掉自己，否则永远显示双勾。
            final readByOthers = lastEvent.receipts.any(
              (r) => r.user.id != myUserId,
            );
            return lastEvent.senderId == myUserId
                ? Icon(
                    readByOthers ? Icons.done_all : Icons.check,
                    color: readByOthers
                        ? const Color(0xFFC6C6C6)
                        : const Color(0xFF919191),
                    size: 18,
                  )
                : AnimatedContainer(
                    duration: TwakeThemes.animationDuration,
                    curve: TwakeThemes.animationCurve,
                    padding: const EdgeInsets.only(bottom: 4),
                    height: ChatListItemStyle.mentionIconWidth,
                    width: isMentioned && room.isUnreadOrInvited
                        ? ChatListItemStyle.mentionIconWidth
                        : 0,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(
                        AppConfig.borderRadius,
                      ),
                    ),
                    child: Center(
                      child: isMentioned && room.isUnreadOrInvited
                          ? Text(
                              '@',
                              style: TextStyle(
                                color: isMentioned
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                fontSize: Theme.of(
                                  context,
                                ).textTheme.labelMedium?.fontSize,
                              ),
                            )
                          : Container(),
                    ),
                  );
          },
        ),
        const SizedBox(width: 4),
        AnimatedContainer(
          duration: TwakeThemes.animationDuration,
          curve: TwakeThemes.animationCurve,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          height: unreadBadgeSize,
          width: ChatListItemStyle.notificationBadgeSize(
            room.isUnreadOrInvited,
            room.hasNewMessages,
            room.notificationCount,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Center(
            child: room.notificationCount > 0
                ? Text(
                    room.notificationCount.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF131314),
                    ),
                  )
                : Container(),
          ),
        ),
      ],
    );
  }

  Widget _buildMainSubtitleContent(
    BuildContext context,
    Event? lastEvent,
    String typingText,
    bool isGroup,
    bool isMediaEvent,
  ) {
    return TypingTimerWrapper(
      room: room,
      l10n: L10n.of(context)!,
      typingWidget: typingTextWidget(typingText, context),
      notTypingWidget: isGroup
          ? chatListItemSubtitleForGroup(
              context: context,
              room: room,
              event: lastEvent,
            )
          : isMediaEvent
          ? chatListItemMediaPreviewSubTitle(context, lastEvent)
          : textContentWidget(
              room,
              lastEvent,
              context,
              isGroup,
              room.isUnreadOrInvited,
            ),
    );
  }
}
