import 'package:flutter/material.dart';
import 'package:flutter_matrix_html/color_extension.dart';

class FileTileWidgetStyle {
  const FileTileWidgetStyle();

  EdgeInsets get paddingFileTileAll =>
      const EdgeInsets.only(left: 8.0, right: 16.0);

  Color backgroundColor(BuildContext context, {bool ownMessage = false}) =>
      ownMessage
      ? Colors.white.withOpacity(0.08)
      : const Color(0xFF2A2A2B).withOpacity(0.40);

  BorderRadiusGeometry get borderRadius => BorderRadius.circular(4.0);

  EdgeInsets get paddingIcon => const EdgeInsets.only(right: 8);

  CrossAxisAlignment get crossAxisAlignment => CrossAxisAlignment.start;

  double get iconSize => 48;

  double get imageSize => 40;

  Color? get fileInfoColor => const Color(0xFF919191);

  TextStyle highlightTextStyle(BuildContext context) {
    return TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      backgroundColor: CssColor.fromCss('gold'),
    );
  }

  TextStyle? textStyle(BuildContext context) {
    return const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontFamily: 'Inter',
    );
  }

  TextStyle textInformationStyle(BuildContext context) {
    return TextStyle(
      color: fileInfoColor,
      fontSize: 12,
      fontFamily: 'Inter',
    );
  }

  EdgeInsets get imagePadding => const EdgeInsets.all(4.0);

  Widget get paddingBottomText => const SizedBox(height: 0.0);

  Widget get paddingRightIcon => const SizedBox(width: 8.0);
}
