import 'package:fluffychat/pages/chat/chat_actions.dart';
import 'package:flutter/material.dart';

typedef OnPickerTypeTap = void Function(PickerType);

class PickerTypeOnBottom extends StatelessWidget {
  final PickerType pickerType;
  final OnPickerTypeTap onPickerTypeTap;

  const PickerTypeOnBottom({
    super.key,
    required this.pickerType,
    required this.onPickerTypeTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onPickerTypeTap.call(pickerType),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              size: 24,
              pickerType.getIcon(),
              color: pickerType.getIconColor(),
            ),
            const SizedBox(height: 4),
            Text(
              pickerType.getTitle(context),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: pickerType.getTextColor(context),
                    letterSpacing: 0.2,
                    fontFamily: 'Inter',
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
