import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/utils/responsive/responsive_utils.dart';
import 'package:flutter/material.dart';

class ChatAppBarTitleStyle {
  static ResponsiveUtils responsive = getIt.get<ResponsiveUtils>();

  static Color get currentlyActiveColor => const Color(0xFF5AD439);

  static Color get currentlyInactiveColor => const Color(0xFF818C99);

  static double get avatarFontSize => 15.0;

  static double avatarSize(BuildContext context) =>
      responsive.isMobile(context) ? 40.0 : 40.0;

  static double get statusSize => 15;

  static Color get statusBorderColor => Colors.white;

  static double get statusBorderSize => 2;

  static double get letterSpacingRoomName => -0.3;

  static double get letterSpacingStatusContent => 1.0;

  static TextStyle? appBarTitleStyle(BuildContext context) => const TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    fontFamily: 'Inter',
    letterSpacing: -0.3,
  );

  static TextStyle? offlineStatusTextStyle(BuildContext context) =>
      const TextStyle(
        color: Color(0x99C6C6C6),
        fontSize: 11,
        fontWeight: FontWeight.w400,
        fontFamily: 'Inter',
        letterSpacing: 1.0,
      );

  static TextStyle? onlineStatusTextStyle(BuildContext context) =>
      const TextStyle(
        color: Color(0x99C6C6C6),
        fontSize: 11,
        fontWeight: FontWeight.w400,
        fontFamily: 'Inter',
        letterSpacing: 1.0,
      );

  static const avatarPadding = EdgeInsetsDirectional.only(end: 12);
}
