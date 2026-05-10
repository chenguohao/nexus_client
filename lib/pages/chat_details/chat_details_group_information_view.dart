import 'package:fluffychat/pages/chat_details/chat_details_view_style.dart';
import 'package:flutter/material.dart';

class ChatDetailsGroupInformationView extends StatefulWidget {
  const ChatDetailsGroupInformationView({
    super.key,
    required this.height,
    required this.maxHeight,
    required this.animationController,
    this.displayName,
    this.subTitle,
    this.onTap,
  });

  final double height;
  final double maxHeight;
  final AnimationController animationController;
  final String? displayName;
  final String? subTitle;
  final VoidCallback? onTap;

  @override
  State<ChatDetailsGroupInformationView> createState() =>
      _ChatDetailsGroupInformationViewState();
}

class _ChatDetailsGroupInformationViewState
    extends State<ChatDetailsGroupInformationView> {
  bool isTextSelected = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SelectionArea(
      onSelectionChanged: (value) {
        final newSelected = value != null && value.plainText.isNotEmpty;
        if (newSelected != isTextSelected) {
          setState(() => isTextSelected = newSelected);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!isTextSelected) {
            widget.onTap?.call();
            return;
          }

          FocusScope.of(context).unfocus();
        },
        child: Container(
          height: Tween<double>(
            begin: widget.height,
            end: widget.maxHeight,
          ).transform(widget.animationController.value),
          padding: ChatDetailViewStyle.mainPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SizedBox(
                height: ChatDetailViewStyle.avatarSize,
                width: ChatDetailViewStyle.avatarSize,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Tween<Alignment>(
                  begin: Alignment.center,
                  end: Alignment.centerLeft,
                ).transform(widget.animationController.value),
                child: Text(
                  widget.displayName ?? '',
                  style: textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFE5E2E3),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.subTitle != null)
                Align(
                  alignment: Tween<Alignment>(
                    begin: Alignment.center,
                    end: Alignment.centerLeft,
                  ).transform(widget.animationController.value),
                  child: Text(
                    widget.subTitle!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF919191),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
