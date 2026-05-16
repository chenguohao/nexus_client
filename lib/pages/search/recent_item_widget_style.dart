import 'package:fluffychat/config/zeon_colors.dart';
import 'package:flutter/material.dart';

class RecentItemStyle {
  static EdgeInsetsGeometry get paddingRecentItem => const EdgeInsets.all(8);

  static double get avatarSize => 56.0;

  static const double recentItemHeight = 80;

  static const TextStyle titleZeon = TextStyle(
    color: ZeonColors.onSurface,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    fontFamily: 'Inter',
    letterSpacing: -0.2,
  );

  static const TextStyle subtitleZeon = TextStyle(
    color: Color(0xFF636363),
    fontSize: 12,
    letterSpacing: 0.25,
    fontFamily: 'Inter',
  );
}
