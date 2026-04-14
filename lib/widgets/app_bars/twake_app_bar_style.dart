import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/utils/responsive/responsive_utils.dart';
import 'package:flutter/material.dart';

class TwakeAppBarStyle {
  static ResponsiveUtils responsiveUtils = getIt.get<ResponsiveUtils>();

  bool isMobile(BuildContext context) => responsiveUtils.isMobile(context);

  static Color appBarBackgroundColor(BuildContext context) =>
      const Color(0xFF131314);

  static TextStyle? titleTextStyle(
    BuildContext context, {
    bool isDialog = false,
  }) => isDialog
      ? Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          height: 32 / 24,
        )
      : const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        );

  static const double dividerHeight = 1.0;
  static const double dividerthickness = 1.0;
  static const EdgeInsets leadingIconPadding = EdgeInsets.only(left: 12);
  static const double leadingIconSize = 24;

  static const EdgeInsetsGeometry backIconPadding = EdgeInsets.symmetric(
    vertical: 8,
    horizontal: 4,
  );
}
