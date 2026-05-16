import 'package:fluffychat/widgets/context_menu_builder_ios_paste_without_permission.dart';
import 'package:fluffychat/widgets/twake_components/twake_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/pages/dialer/pip/dismiss_keyboard.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

class SearchTextField extends StatelessWidget {
  final TextEditingController textEditingController;
  final bool autofocus;
  final String? hintText;
  final FocusNode? focusNode;

  const SearchTextField({
    super.key,
    required this.textEditingController,
    this.autofocus = true,
    this.hintText,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.zero,
      child: TextField(
        onTapOutside: (event) {
          dismissKeyboard(context);
        },
        controller: textEditingController,
        textInputAction: TextInputAction.search,
        contextMenuBuilder: mobileTwakeContextMenuBuilder,
        enabled: true,
        focusNode: focusNode,
        autofocus: autofocus,
        cursorColor: ZeonColors.onSurface,
        style: const TextStyle(
          color: ZeonColors.onSurface,
          fontSize: 14,
          letterSpacing: 0.25,
        ),
        decoration: InputDecoration(
          filled: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          fillColor: ZeonColors.surfaceContainerLow,
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0x0DFFFFFF)),
            borderRadius: BorderRadius.zero,
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0x0DFFFFFF)),
            borderRadius: BorderRadius.zero,
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0x4DFFFFFF)),
            borderRadius: BorderRadius.zero,
          ),
          hintText: hintText ?? 'SEARCH DIRECTORY',
          hintStyle: const TextStyle(
            color: ZeonColors.outline,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          prefixIcon: const Icon(
            Icons.search_outlined,
            size: 20,
            color: ZeonColors.outline,
          ),
          suffixIcon: ValueListenableBuilder(
            valueListenable: textEditingController,
            builder: (context, value, child) {
              return value.text.isNotEmpty ? child! : const SizedBox.shrink();
            },
            child: TwakeIconButton(
              tooltip: L10n.of(context)!.close,
              icon: Icons.close,
              iconColor: ZeonColors.onSurface,
              onTap: () {
                textEditingController.clear();
              },
            ),
          ),
        ),
      ),
    );
  }
}
