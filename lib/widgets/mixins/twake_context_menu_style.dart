import 'package:flutter/material.dart';

class TwakeContextMenuStyle {
  static Color defaultMenuColor(BuildContext context) {
    return const Color(0xFF1C1B1C);
  }

  static Color defaultItemColorIcon(BuildContext context) {
    return const Color(0xFFE5E2E3);
  }

  static const double defaultVerticalPadding = 0.0;
  static const double menuElevation = 2.0;
  static const double menuBorderRadius = 0.0;
  static const double menuMinWidth = 196.0;
  static const double menuMaxWidth = 306.0;
  static const double defaultItemIconSize = 24.0;
  static const EdgeInsets defaultItemPadding = EdgeInsets.symmetric(
    vertical: 11.0,
    horizontal: 16.0,
  );
  static const double defaultItemElementsGap = 12.0;

  static TextStyle defaultItemTextStyle(BuildContext context) {
    return const TextStyle(
      color: Color(0xFFE5E2E3),
      fontSize: 14,
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400,
    );
  }
}
