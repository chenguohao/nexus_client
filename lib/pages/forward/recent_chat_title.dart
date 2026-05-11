import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class RecentChatsTitle extends StatelessWidget {
  const RecentChatsTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Row(
        children: [
          Text(
            L10n.of(context)!.recentChat,
            style: const TextStyle(
              color: Color(0xFF636363),
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
