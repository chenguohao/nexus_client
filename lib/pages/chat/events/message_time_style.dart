import 'package:flutter/material.dart';

class MessageTimeStyle {
  static Color? timelineColor(bool timelineOverlayMessage) =>
      timelineOverlayMessage
      ? Colors.white
      : Colors.white.withOpacity(0.40);

  static double get timelineLetterSpacing => 0.4;

  static double get paddingTimeAndIcon => 8;
  static double get seenByRowIconSize => 16;
  static Color seenByRowIconPrimaryColor(
    bool timelineOverlayMessage,
    BuildContext context,
  ) => Colors.white;
  static Color seenByRowIconSecondaryColor(
    bool timelineOverlayMessage,
    BuildContext context,
  ) => timelineOverlayMessage
      ? Colors.white
      : Colors.white.withOpacity(0.40);

  static TextStyle? textStyle(
    BuildContext context,
    bool timelineOverlayMessage,
  ) => TextStyle(
    color: timelineColor(timelineOverlayMessage),
    fontSize: 9,
    letterSpacing: 0.4,
    fontFamily: 'Inter',
  );
}
