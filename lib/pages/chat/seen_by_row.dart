import 'package:fluffychat/pages/chat/events/message_time_style.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

enum MessageStatus { sending, sent, hasBeenSeen, error }

class SeenByRow extends StatelessWidget {
  final List<User> getSeenByUsers;
  final List<User> participants;
  final EventStatus? eventStatus;
  final bool timelineOverlayMessage;
  final Event event;

  const SeenByRow({
    this.eventStatus,
    super.key,
    required this.getSeenByUsers,
    required this.participants,
    required this.timelineOverlayMessage,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return getEventIcon(context, getSeenByUsers, eventStatus: eventStatus);
  }

  MessageStatus getMessageStatus(
    BuildContext context,
    List<User> seenByUsers, {
    EventStatus? eventStatus,
  }) {
    if (eventStatus == EventStatus.error) {
      return MessageStatus.error;
    }

    if (eventStatus == null || eventStatus == EventStatus.sending) {
      return MessageStatus.sending;
    }

    if (eventStatus == EventStatus.sent || seenByUsers.isEmpty) {
      return MessageStatus.sent;
    }

    return MessageStatus.hasBeenSeen;
  }

  Widget getEventIcon(
    BuildContext context,
    List<User> seenByUsers, {
    bool? oldMessageFullyRead,
    EventStatus? eventStatus,
  }) {
    final messageStatus = getMessageStatus(
      context,
      seenByUsers,
      eventStatus: eventStatus,
    );
    switch (messageStatus) {
      case MessageStatus.sending:
        return Icon(
          Icons.schedule,
          color: MessageTimeStyle.seenByRowIconSecondaryColor(
            timelineOverlayMessage,
            context,
          ),
          size: MessageTimeStyle.seenByRowIconSize,
        );
      case MessageStatus.sent:
        // 服务器已收到、还没有任何人读过 → 单勾（Telegram 约定）。
        // 给不存在 / 不上线的用户发消息会一直停在这个状态。
        return Icon(
          Icons.check,
          color: MessageTimeStyle.seenByRowIconSecondaryColor(
            timelineOverlayMessage,
            context,
          ),
          size: MessageTimeStyle.seenByRowIconSize,
        );
      case MessageStatus.hasBeenSeen:
        // 至少一个接收方设备发过 m.read → 双勾（Telegram 约定的"已读"）。
        return Icon(
          Icons.done_all,
          color: MessageTimeStyle.seenByRowIconPrimaryColor(
            timelineOverlayMessage,
            context,
          ),
          size: MessageTimeStyle.seenByRowIconSize,
        );
      case MessageStatus.error:
        return Icon(
          Icons.error,
          color: Theme.of(context).colorScheme.error,
          size: MessageTimeStyle.seenByRowIconSize,
        );
    }
  }
}
