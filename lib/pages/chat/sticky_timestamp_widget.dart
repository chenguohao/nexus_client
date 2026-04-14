import 'package:flutter/material.dart';

class StickyTimestampWidget extends StatelessWidget {
  final String content;
  final bool isStickyHeader;

  const StickyTimestampWidget({
    super.key,
    required this.content,
    this.isStickyHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: UnconstrainedBox(
        child: Opacity(
          opacity: isStickyHeader ? 0.8 : 1.0,
          child: Container(
            margin: const EdgeInsets.only(top: 8.0),
            decoration: isStickyHeader
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: const Color(0xFF201F20),
                  )
                : null,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                children: [
                  Text(
                    content,
                    style: const TextStyle(
                      color: Color(0xFF919191),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      letterSpacing: 1.0,
                    ),
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
