import 'package:fluffychat/widgets/context_menu_builder_ios_paste_without_permission.dart';
import 'package:fluffychat/widgets/twake_components/twake_icon_button.dart';
import 'package:flutter/material.dart';
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
      borderRadius: BorderRadius.circular(8),
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
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
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
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0x66FFFFFF)),
            borderRadius: BorderRadius.circular(8),
          ),
          hintText: hintText ?? 'SEARCH DIRECTORY',
          hintStyle: const TextStyle(
            color: Color(0xFF919191),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          prefixIcon: const Icon(
            Icons.search_outlined,
            size: 20,
            color: Color(0xFF919191),
          ),
          suffixIcon: ValueListenableBuilder(
            valueListenable: textEditingController,
            builder: (context, value, child) {
              return value.text.isNotEmpty ? child! : const SizedBox.shrink();
            },
            child: TwakeIconButton(
              tooltip: L10n.of(context)!.close,
              icon: Icons.close,
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
