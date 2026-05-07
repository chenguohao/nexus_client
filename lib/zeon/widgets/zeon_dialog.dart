import 'package:flutter/material.dart';

/// Zeon-styled dialog utilities.
///
/// All dialogs follow the "Sovereign Skeletalism" design language:
/// - Background: [Color(0xFF1C1B1C)]
/// - Sharp corners (4 px max)
/// - White / gray / red-tinted text, no blue buttons
abstract class ZeonDialog {
  ZeonDialog._();

  static const _kShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
  );

  static const _kTitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  static const _kBodyStyle = TextStyle(
    color: Color(0xFFC6C6C6),
    fontSize: 13,
    height: 1.5,
  );

  static const _kCancelStyle = TextStyle(
    color: Color(0xFFC6C6C6),
    letterSpacing: 1.4,
    fontWeight: FontWeight.w600,
  );

  static TextStyle _okStyle({bool destructive = false}) => TextStyle(
    color: destructive ? const Color(0xFFFFB4AB) : Colors.white,
    letterSpacing: 1.4,
    fontWeight: FontWeight.w700,
  );

  // ── Confirm (ok + cancel) ────────────────────────────────────────────────

  /// Shows a Zeon-styled confirmation dialog.
  ///
  /// Returns `true` when the user taps [okLabel], `false` otherwise.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String okLabel = '确认',
    String cancelLabel = '取消',
    bool destructive = false,
    bool barrierDismissible = true,
    bool useRootNavigator = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B1C),
        shape: _kShape,
        title: Text(title, style: _kTitleStyle),
        content: message != null
            ? Text(message, style: _kBodyStyle)
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel, style: _kCancelStyle),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okLabel, style: _okStyle(destructive: destructive)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Alert (ok only) ───────────────────────────────────────────────────────

  /// Shows a Zeon-styled informational / error dialog with a single OK button.
  static Future<void> alert(
    BuildContext context, {
    required String title,
    String? message,
    String okLabel = 'OK',
    bool useRootNavigator = false,
  }) {
    return showDialog<void>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B1C),
        shape: _kShape,
        title: Text(title, style: _kTitleStyle),
        content: message != null
            ? Text(message, style: _kBodyStyle)
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(okLabel, style: _okStyle()),
          ),
        ],
      ),
    );
  }
}
