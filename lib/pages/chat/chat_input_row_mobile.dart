import 'package:fluffychat/pages/chat/chat_input_row_style.dart';
import 'package:flutter/material.dart';

typedef OnTapEmojiAction = void Function();

class ChatInputRowMobile extends StatelessWidget {
  const ChatInputRowMobile({super.key, required this.inputBar});

  final Widget inputBar;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: ChatInputRowStyle.chatInputRowHeight,
      ),
      child: Container(
        alignment: Alignment.center,
        padding: ChatInputRowStyle.chatInputRowPaddingMobile,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: const Color(0xFF0E0E0F),
          border: Border.all(
            color: const Color(0x0DFFFFFF),
            width: 1,
          ),
        ),
        child: Row(children: [Expanded(child: inputBar)]),
      ),
    );
  }
}
