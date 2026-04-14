import 'package:fluffychat/pages/chat/events/button_content_style.dart';
import 'package:flutter/material.dart';

class ButtonContent extends StatelessWidget {
  final Function onTap;
  final IconData icon;
  final String title;

  const ButtonContent({
    super.key,
    required this.onTap,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ButtonContentStyle.parentPadding,
      child: InkWell(
        onTap: () => onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  padding: ButtonContentStyle.leadingIconPadding,
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: ButtonContentStyle.leadingIconSize,
                  ),
                ),
                const SizedBox(width: ButtonContentStyle.leadingAndTextGap),
                Container(
                  constraints: const BoxConstraints(
                    maxWidth: ButtonContentStyle.textMaxWidth,
                  ),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC6C6C6),
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
