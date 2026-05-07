import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

enum DialogRejectInviteResult { reject, cancel }

class DialogRejectInviteWidget extends StatelessWidget {
  const DialogRejectInviteWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1B1C),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: const Color(0x4D474747)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.declineTheInvitation.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.doYouReallyWantToDeclineThisInvitation,
                style: const TextStyle(
                  color: Color(0xFFC6C6C6),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ZeonButton(
                    text: l10n.cancel,
                    primary: false,
                    onPressed: () => Navigator.of(context)
                        .pop(DialogRejectInviteResult.cancel),
                  ),
                  const SizedBox(width: 8),
                  _ZeonButton(
                    text: l10n.declineAndRemove,
                    primary: true,
                    destructive: true,
                    onPressed: () => Navigator.of(context)
                        .pop(DialogRejectInviteResult.reject),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZeonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool primary;
  final bool destructive;

  const _ZeonButton({
    required this.text,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.zero,
          border: primary ? null : Border.all(color: const Color(0x33474747)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: destructive
                ? const Color(0xFFFFB4AB)
                : primary
                    ? const Color(0xFF131314)
                    : const Color(0xFFC6C6C6),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
