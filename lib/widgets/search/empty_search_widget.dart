import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

class EmptySearchWidget extends StatelessWidget {
  const EmptySearchWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1B1C),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: const Color(0x33474747)),
            ),
            child: const Icon(
              Icons.search_off,
              size: 26,
              color: Color(0xCCC6C6C6),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'NO RESULTS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xCCC6C6C6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            L10n.of(context)!.noResults,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try a different keyword.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xB3C6C6C6),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
