import 'package:flutter/material.dart';

/// Slim linear upload indicator for chat bubbles (Zeon palette, no rounded caps).
class ZeonLinearUploadProgress extends StatelessWidget {
  const ZeonLinearUploadProgress({
    super.key,
    this.value,
    this.minHeight = 4,
  });

  /// Null ⇒ indeterminate (encrypt / thumbnail / unknown phase).
  final double? value;

  final double minHeight;

  static const Color _track = Color(0xFF2C2C2C);
  static const Color _fill = Color(0xFFE5E2E3);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: minHeight,
      width: double.infinity,
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: _track,
        color: _fill,
        minHeight: minHeight,
      ),
    );
  }
}
