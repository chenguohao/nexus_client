import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/utils/responsive/responsive_utils.dart';
import 'package:flutter/material.dart';

class GroupChatEmptyViewStyle {
  static final ResponsiveUtils responsiveUtils = getIt.get<ResponsiveUtils>();

  static const double _nonMobileMaxWidth = 442;

  static TextStyle titleStyle(BuildContext context) {
    return const TextStyle(
      color: Color(0xFFE5E2E3),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.0,
    );
  }

  static TextStyle ruleStyle(BuildContext context) {
    return const TextStyle(
      color: Color(0xFF919191),
      fontSize: 12,
      letterSpacing: 0.3,
      fontWeight: FontWeight.w400,
    );
  }

  static double maxWidth(BuildContext context) {
    if (responsiveUtils.isMobile(context)) {
      return minWidth;
    } else {
      return _nonMobileMaxWidth;
    }
  }

  static const double minWidth = 300;
}
