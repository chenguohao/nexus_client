import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

typedef OnAcceptButton = void Function()?;
typedef OnRefuseTap = void Function()?;

class PermissionDialog extends StatefulWidget {
  final Permission permission;

  final Widget explainTextRequestPermission;

  final Widget? titleTextRequestPermission;

  final Widget? customButtonRow;

  final Widget? icon;

  final OnAcceptButton onAcceptButton;

  final OnRefuseTap onRefuseTap;

  const PermissionDialog({
    super.key,
    required this.permission,
    required this.explainTextRequestPermission,
    this.icon,
    this.onAcceptButton,
    this.onRefuseTap,
    this.titleTextRequestPermission,
    this.customButtonRow,
  });

  @override
  State<PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<PermissionDialog>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const zeonBody = TextStyle(
      color: ZeonColors.outline,
      fontSize: 14,
      fontFamily: 'Inter',
      letterSpacing: 0.25,
      height: 1.35,
    );
    const zeonTitle = TextStyle(
      color: ZeonColors.onSurface,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      fontFamily: 'Inter',
      letterSpacing: -0.3,
      height: 1.25,
    );

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.copyWith(
          bodyMedium: zeonBody,
          bodyLarge: zeonBody,
          headlineSmall: zeonTitle,
          titleLarge: zeonTitle,
        ),
      ),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Material(
          color: ZeonColors.surfaceContainerLow,
          borderRadius: BorderRadius.zero,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              border: Border.all(color: const Color(0x33474747)),
              color: ZeonColors.surfaceContainerLow,
            ),
            width: MediaQuery.sizeOf(context).width * 0.85,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    IconTheme.merge(
                      data: const IconThemeData(
                        color: ZeonColors.onSurface,
                        size: 36,
                      ),
                      child: widget.icon!,
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (widget.titleTextRequestPermission != null) ...[
                    DefaultTextStyle.merge(
                      style: zeonTitle,
                      child: widget.titleTextRequestPermission!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  DefaultTextStyle.merge(
                    style: zeonBody,
                    child: widget.explainTextRequestPermission,
                  ),
                  const SizedBox(height: 22),
                  widget.customButtonRow ??
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!PlatformInfos.isIOS)
                            PermissionTextButton(
                              context: context,
                              text: L10n.of(context)!.deny,
                              textStyle: const TextStyle(
                                color: ZeonColors.outline,
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              onPressed: () {
                                widget.onRefuseTap?.call();
                                Navigator.of(context).pop();
                              },
                            ),
                          if (!PlatformInfos.isIOS) const SizedBox(width: 8),
                          PermissionTextButton(
                            context: context,
                            text: L10n.of(context)!.next,
                            decoration: const BoxDecoration(
                              color: ZeonColors.primary,
                              borderRadius: BorderRadius.zero,
                            ),
                            textStyle: const TextStyle(
                              color: ZeonColors.onPrimary,
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            onPressed: () async {
                              if (widget.onAcceptButton != null) {
                                widget.onAcceptButton!.call();
                              } else {
                                await widget.permission.request().then(
                                  (value) => Navigator.of(context).pop(),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PermissionTextButton extends StatelessWidget {
  const PermissionTextButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.context,
    this.decoration,
    this.textStyle,
    this.padding,
  });

  final String text;
  final VoidCallback? onPressed;
  final BuildContext context;
  final Decoration? decoration;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: onPressed,
        child: Container(
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: decoration,
          child: Text(
            text,
            style:
                textStyle ??
                const TextStyle(
                  color: ZeonColors.outline,
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
          ),
        ),
      ),
    );
  }
}
