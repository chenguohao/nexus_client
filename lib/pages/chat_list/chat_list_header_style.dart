import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/utils/responsive/responsive_utils.dart';
import 'package:flutter/material.dart';

class ChatListHeaderStyle {
  static ResponsiveUtils responsive = getIt.get<ResponsiveUtils>();

  static const double searchRadiusBorder = 24.0;
  static const double searchBarContainerHeight = 57.0;
  static const double searchIconSize = 24.0;

  static const EdgeInsetsDirectional searchInputPadding =
      EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 8);

  static const EdgeInsetsDirectional paddingZero = EdgeInsetsDirectional.zero;

  static InputDecoration searchInputDecoration(
    BuildContext context, {
    String? hintText,
    Color? prefixIconColor,
  }) {
    return InputDecoration(
      filled: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      fillColor: const Color(0xFF0E0E0F),
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0x33474747)),
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0x33474747)),
        borderRadius: BorderRadius.circular(8),
      ),
      disabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0x33474747)),
        borderRadius: BorderRadius.circular(8),
      ),
      hintText: hintText ?? 'Search secure communications...',
      hintStyle: const TextStyle(
        color: Color(0xFFC6C6C6),
        fontSize: 14,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      prefixIcon: Icon(
        Icons.search,
        size: ChatListHeaderStyle.searchIconSize,
        color: prefixIconColor ?? const Color(0xFFC6C6C6),
      ),
      suffixIcon: const SizedBox.shrink(),
    );
  }

  static const dividerHeight = 1.0;
  static const dividerThickness = 1.0;
}
