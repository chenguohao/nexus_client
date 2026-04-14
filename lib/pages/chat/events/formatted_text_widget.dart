import 'package:fluffychat/pages/chat/events/html_message.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart' hide Visibility;

class FormattedTextWidget extends StatelessWidget {
  final Event event;
  final double fontSize;
  final TextStyle? linkStyle;

  const FormattedTextWidget({
    super.key,
    required this.event,
    required this.fontSize,
    this.linkStyle,
  });

  @override
  Widget build(BuildContext context) {
    var html = event.formattedText;

    if (event.messageType == MessageTypes.Emote) {
      html = '* $html';
    }
    final bigEmotes =
        event.onlyEmotes && event.numberEmotes > 0 && event.numberEmotes <= 10;

    return HtmlMessage(
      html: html,
      defaultTextStyle: TextStyle(
        color: event.isOwnMessage ? Colors.white : const Color(0xFFE5E2E3),
        fontSize: 15,
        fontFamily: 'Inter',
        height: 1.5,
      ),
      linkStyle: linkStyle,
      room: event.room,
      emoteSize: bigEmotes ? fontSize * 3 : fontSize * 1.5,
    );
  }
}
