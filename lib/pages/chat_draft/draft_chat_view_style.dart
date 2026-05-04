import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/pages/chat/chat_input_row_style.dart';
import 'package:fluffychat/utils/responsive/responsive_utils.dart';
import 'package:flutter/material.dart';

class DraftChatViewStyle {
  static ResponsiveUtils responsive = getIt.get<ResponsiveUtils>();

  static BoxConstraints get containerMaxWidthConstraints =>
      const BoxConstraints(maxWidth: TwakeThemes.columnWidth * 2.5);

  static int get minLinesInputBar => 1;

  static int get maxLinesInputBar => 8;

  static InputDecoration bottomBarInputDecoration(BuildContext context) =>
      InputDecoration(
        hintText: 'EXECUTE MESSAGE...',
        isDense: true,
        hintMaxLines: 1,
        contentPadding: ChatInputRowStyle.contentPadding(context),
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.40),
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: 2.0,
        ),
      );

  static double bottomBarInputPadding(BuildContext context) =>
      responsive.isMobile(context) ? 8.0 : 8.0;

  static EdgeInsetsGeometry get emptyChatChildrenPadding =>
      const EdgeInsetsDirectional.only(end: 8);
  static const double emptyChatGapWidth = 12.0;

  static const EdgeInsetsGeometry iconSendPadding = EdgeInsetsDirectional.only(
    end: 8.0,
    start: 8,
    bottom: 8,
  );
}
