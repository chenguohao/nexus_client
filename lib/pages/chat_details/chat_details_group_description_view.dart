import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ChatDetailsGroupDescriptionView extends StatefulWidget {
  const ChatDetailsGroupDescriptionView({
    super.key,
    required this.topic,
    required this.onHeightCalculated,
  });

  final String topic;
  final void Function(double height) onHeightCalculated;

  @override
  State<ChatDetailsGroupDescriptionView> createState() =>
      _ChatDetailsGroupDescriptionViewState();
}

class _ChatDetailsGroupDescriptionViewState
    extends State<ChatDetailsGroupDescriptionView> {
  final key = GlobalKey();
  String description = '';

  void calculateHeight() {
    if (!mounted) return;
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && mounted) {
      widget.onHeightCalculated(renderBox.size.height);
    }
  }

  @override
  void initState() {
    super.initState();
    description = widget.topic.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      calculateHeight();
    });
  }

  @override
  void didUpdateWidget(ChatDetailsGroupDescriptionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topic != widget.topic) {
      setState(() {
        description = widget.topic.trim();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        calculateHeight();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => calculateHeight());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final displayText = description.isEmpty ? l10n.noDescription : description;

    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1B1C),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x33474747)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DESCRIPTION',
            style: TextStyle(
              color: Color(0xFF919191),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            displayText,
            style: textTheme.bodySmall?.copyWith(
              color: description.isEmpty
                  ? const Color(0xFF636363)
                  : const Color(0xFFE5E2E3),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
