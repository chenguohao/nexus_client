import 'package:collection/collection.dart';
import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:fluffychat/pages/contacts_tab/widgets/add_contact/add_contact_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AddContactDialogViewWeb extends StatelessWidget {
  const AddContactDialogViewWeb({super.key, required this.controller});

  final AddContactDialogController controller;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onClose: () => Navigator.pop(context)),
            const SizedBox(height: 32),
            _MatrixIdField(controller: controller),
            const SizedBox(height: 40),
            _Actions(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text(
            'New Contact',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              height: 32 / 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: ZeonColors.primary,
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: const Icon(
            Icons.close,
            size: 20,
            color: ZeonColors.onSurfaceVariant,
          ),
          tooltip: L10n.of(context)!.close,
        ),
      ],
    );
  }
}

/// 通用 Sovereign 字段：UPPERCASE label + 单行输入框 + 1px ghost underline
class _SovereignField extends StatefulWidget {
  const _SovereignField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.errorMessage,
    this.maxLength,
    this.autoFocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.helperText,
    this.prefixText,
  });

  final String label;
  final ValueListenable<String> value;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final String? errorMessage;
  final int? maxLength;
  final bool autoFocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? helperText;
  final String? prefixText;

  @override
  State<_SovereignField> createState() => _SovereignFieldState();
}

class _SovereignFieldState extends State<_SovereignField> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.value.value);
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _focusNode.hasFocus;
    final hasError = widget.errorMessage != null;
    final underlineColor = hasError
        ? ZeonColors.error
        : isFocused
        ? ZeonColors.primary
        : ZeonColors.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                height: 16 / 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: ZeonColors.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (widget.maxLength != null)
              ValueListenableBuilder<String>(
                valueListenable: widget.value,
                builder: (context, value, _) => Text(
                  '${value.length}/${widget.maxLength}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    height: 16 / 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                    color: ZeonColors.outline,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _textController,
          focusNode: _focusNode,
          autofocus: widget.autoFocus,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          textInputAction: widget.textInputAction,
          cursorColor: ZeonColors.primary,
          cursorWidth: 1,
          inputFormatters: widget.maxLength != null
              ? AddContactDialogController.lengthLimit(widget.maxLength!)
              : null,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            height: 24 / 17,
            fontWeight: FontWeight.w400,
            color: ZeonColors.primary,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.only(bottom: 8),
            hintText: widget.hintText,
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              height: 24 / 17,
              fontWeight: FontWeight.w400,
              color: ZeonColors.outline,
            ),
            prefixText: widget.prefixText,
            prefixStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              height: 24 / 17,
              fontWeight: FontWeight.w400,
              color: ZeonColors.outline,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            counterText: '',
          ),
        ),
        Container(height: 1, color: underlineColor),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorMessage!,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w500,
              color: ZeonColors.error,
            ),
          ),
        ] else if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.helperText!,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w400,
              color: ZeonColors.outline,
            ),
          ),
        ],
      ],
    );
  }
}

class _MatrixIdField extends StatelessWidget {
  const _MatrixIdField({required this.controller});

  final AddContactDialogController controller;

  @override
  Widget build(BuildContext context) {
    final defaultServer = controller.defaultServerName;
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller.userName,
        controller.usernameErrorMessage,
      ]),
      builder: (context, _) {
        // 用户主动输入完整 mxid（@开头）时，切回完整模式
        final raw = controller.userName.value;
        final useFullMxid = raw.startsWith('@') || defaultServer == null;
        return _SovereignField(
          label: 'ZEON ID',
          value: controller.userName,
          onChanged: controller.onUsernameChanged,
          hintText: useFullMxid ? '@example:zeon.chat' : 'Zeon ID',
          errorMessage: controller.usernameErrorMessage.value,
          prefixText: useFullMxid ? null : '@',
          textInputAction: TextInputAction.done,
          autoFocus: true,
          onSubmitted: (_) => controller.onSave(),
        );
      },
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.controller});

  final AddContactDialogController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GhostButton(
            label: L10n.of(context)!.cancel.toUpperCase(),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedBuilder(
            animation: controller.userName,
            builder: (context, _) {
              final mxid = controller.resolvedMxid;
              final existedContact = controller.availableContacts
                  .firstWhereOrNull(
                    (contact) => contact.matrixId == mxid,
                  );
              final enabled = controller.canSubmit;
              return _SovereignButton(
                label: existedContact != null
                    ? L10n.of(context)!.sendMessage.toUpperCase()
                    : L10n.of(context)!.confirm.toUpperCase(),
                enabled: enabled,
                onPressed: enabled ? controller.onSave : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SovereignButton extends StatelessWidget {
  const _SovereignButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? ZeonColors.primary : ZeonColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: enabled ? ZeonColors.onPrimary : ZeonColors.outline,
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: ZeonColors.outlineVariant, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: ZeonColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
