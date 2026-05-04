import 'package:fluffychat/pages/chat_draft/draft_chat_empty_widget_style.dart';
import 'package:flutter/material.dart';

class DraftChatEmpty extends StatelessWidget {
  const DraftChatEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: DraftChatEmptyWidgetStyle.maxWidth(context),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1B1C),
            border: Border.all(color: const Color(0x33474747)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bolt_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'SESSION ESTABLISHED',
                    style: TextStyle(
                      color: Color(0xCCC6C6C6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18),
              Text(
                'NO TRANSMISSIONS YET',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Send a message to begin the conversation.',
                style: TextStyle(
                  color: Color(0xB3C6C6C6),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Inter',
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
