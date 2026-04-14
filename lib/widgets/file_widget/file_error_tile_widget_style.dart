import 'package:fluffychat/widgets/file_widget/file_tile_widget_style.dart';
import 'package:flutter/material.dart';

class FileErrorTileWidgetStyle extends FileTileWidgetStyle {
  @override
  Color? get fileInfoColor => Colors.redAccent;

  @override
  TextStyle textInformationStyle(BuildContext context) {
    return TextStyle(
      color: fileInfoColor,
      fontSize: 12,
      fontFamily: 'Inter',
    );
  }

  @override
  TextStyle? textStyle(BuildContext context) {
    return const TextStyle(
      color: Colors.redAccent,
      fontSize: 14,
      fontFamily: 'Inter',
    );
  }
}
