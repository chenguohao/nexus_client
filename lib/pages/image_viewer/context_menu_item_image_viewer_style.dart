import 'package:flutter/material.dart';

class ContextMenuItemImageViewerStyle {
  static const double width = 200;

  static const double height = 48;

  static const double dividerHeight = 1;

  static Color dividerColor(BuildContext context) =>
      const Color(0x1F474747);

  static SizedBox get paddingBetweenItems => const SizedBox(width: 12);
}
