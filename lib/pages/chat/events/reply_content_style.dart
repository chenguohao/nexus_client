import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/utils/responsive/responsive_utils.dart';
import 'package:flutter/material.dart';

class ReplyContentStyle {
  static ResponsiveUtils responsive = getIt.get<ResponsiveUtils>();
  static const double fontSizeDisplayName = AppConfig.messageFontSize * 0.76;
  static const double fontSizeDisplayContent = AppConfig.messageFontSize * 0.88;
  static const double replyContentSize = fontSizeDisplayContent * 2;

  static const EdgeInsets replyParentContainerPadding = EdgeInsets.only(
    left: 4,
    right: 8.0,
    top: 8.0,
    bottom: 8.0,
  );

  static BoxDecoration replyParentContainerDecoration(
    BuildContext context,
    bool ownMessage,
  ) {
    return BoxDecoration(
      color: ownMessage
          ? Colors.white.withOpacity(0.08)
          : const Color(0xFF2A2A2B).withOpacity(0.40),
      borderRadius: BorderRadius.circular(4.0),
    );
  }

  static const double prefixBarWidth = 3.0;
  static const double prefixBarVerticalPadding = 4.0;
  static BoxDecoration prefixBarDecoration(BuildContext context) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(2),
      color: Colors.white.withOpacity(0.40),
    );
  }

  static const double contentSpacing = 6.0;
  static const BorderRadius previewedImageBorderRadius = BorderRadius.all(
    Radius.circular(4),
  );
  static const double previewedImagePlaceholderPadding = 4.0;

  static TextStyle? displayNameTextStyle(BuildContext context) {
    return const TextStyle(
      color: Color(0xFFC6C6C6),
      fontWeight: FontWeight.bold,
      fontSize: fontSizeDisplayName,
      fontFamily: 'Inter',
    );
  }

  static TextStyle? replyBodyTextStyle(BuildContext context) {
    return const TextStyle(
      color: Color(0xFF919191),
      fontWeight: FontWeight.w500,
      overflow: TextOverflow.ellipsis,
      fontSize: fontSizeDisplayContent,
      fontFamily: 'Inter',
    );
  }

  static EdgeInsetsDirectional get marginReplyContent =>
      EdgeInsetsDirectional.symmetric(
        vertical: 4.0 * AppConfig.bubbleSizeFactor,
      );

  static const double replyContainerHeight = 60;
}
