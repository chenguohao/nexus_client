import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class ChatDetailsGroupActionsView extends StatelessWidget {
  const ChatDetailsGroupActionsView({
    super.key,
    required this.onMessage,
    required this.onSearch,
    this.onToggleNotification,
    this.muteNotifier,
    required this.animationController,
  });

  // Keep the same constructor signature so callers don't need to change.
  final VoidCallback onMessage;
  final VoidCallback onSearch;
  final VoidCallback? onToggleNotification;
  final ValueNotifier<PushRuleState>? muteNotifier;
  final AnimationController animationController;

  @override
  Widget build(BuildContext context) {
    if (muteNotifier == null) return const SizedBox.shrink();

    return ValueListenableBuilder<PushRuleState>(
      valueListenable: muteNotifier!,
      builder: (context, value, _) {
        final isMuted = value != PushRuleState.notify;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1B1C),
            border: Border.fromBorderSide(
              BorderSide(color: Color(0x33474747)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isMuted
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_outlined,
                color: isMuted
                    ? const Color(0xFF636363)
                    : const Color(0xFFE5E2E3),
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '免打扰',
                  style: TextStyle(
                    color: Color(0xFFE5E2E3),
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Switch(
                value: isMuted,
                onChanged: (_) => onToggleNotification?.call(),
                activeColor: const Color(0xFFE5E2E3),
                activeTrackColor: const Color(0xFF474747),
                inactiveThumbColor: const Color(0xFF636363),
                inactiveTrackColor: const Color(0xFF2A2A2B),
              ),
            ],
          ),
        );
      },
    );
  }
}
