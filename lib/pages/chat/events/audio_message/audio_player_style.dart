import 'package:fluffychat/pages/chat/events/message/message_style.dart';
import 'package:flutter/material.dart';

class AudioPlayerStyle {
  static const minWaveCount = 32;

  static const maxWaveWidth = 4.0;

  static const maxBodyContentWidth = 88.0;

  static int maxWaveCount(BuildContext context) {
    return (MessageStyle.messageBubbleWidth(context) - maxBodyContentWidth) ~/
        maxWaveWidth;
  }

  static const minWaveHeight = 4.0;

  static const maxWaveHeight = 26.0;

  static TextStyle? textInformationStyle(BuildContext context) =>
      const TextStyle(
        color: Color(0xFFC6C6C6),
        fontSize: 10,
        fontFamily: 'Inter',
        fontFeatures: [FontFeature.tabularFigures()],
      );
}
