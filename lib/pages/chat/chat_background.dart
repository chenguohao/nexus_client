import 'package:flutter/material.dart';

class ChatBackground extends StatelessWidget {
  const ChatBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: ColoredBox(color: Color(0xFF131314)),
    );
  }
}
