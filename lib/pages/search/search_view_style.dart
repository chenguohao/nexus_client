import 'package:flutter/material.dart';
import 'package:fluffychat/config/zeon_colors.dart';

class SearchViewStyle {
  static double get toolbarHeightSearch => 56.0;

  static double get toolbarHeightOfSliverAppBar => 44.0;

  static EdgeInsetsGeometry get paddingRecentChatsHeaders =>
      const EdgeInsets.symmetric(horizontal: 16);

  static EdgeInsetsGeometry get paddingLeadingAppBar =>
      const EdgeInsetsDirectional.only(end: 8, start: 8);

  static EdgeInsetsGeometry get contentPaddingAppBar =>
      const EdgeInsets.all(12.0);

  static EdgeInsetsGeometry get paddingRecentChats => const EdgeInsets.all(8);

  static const double paddingBackButton = 8.0;

  static EdgeInsetsGeometry get appbarPadding =>
      const EdgeInsetsDirectional.only(bottom: 0.0, top: 0.0);

  /// Zeon 分区标题样式（对齐通讯录等板块）
  static const TextStyle sectionHeaderZeon = TextStyle(
    color: ZeonColors.outline,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    fontFamily: 'Inter',
    letterSpacing: 1.8,
  );

  static const double searchIconSize = 24.0;
}
