import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

/// Lightweight Zeon-themed toast utility built on top of `flutter_easyloading`.
///
/// Pure text, monochrome — matches the rest of the Zeon UI (no accent colours).
///
/// Usage:
/// ```dart
/// Toast.success('资料已更新'); // same visual as Toast.show, semantic intent only
/// Toast.error('保存失败');
/// Toast.info('正在同步');
/// Toast.show('自定义文本');
/// ```
///
/// Call `Toast.configure()` once at app start (before `runApp`) so the global
/// EasyLoading theme matches Zeon (dark, sharp, monochrome).
abstract class Toast {
  /// Configure global EasyLoading theme to match Zeon design tokens.
  static void configure() {
    EasyLoading.instance
      ..displayDuration = const Duration(milliseconds: 2200)
      ..backgroundColor = const Color(0xFF1C1B1C)
      ..textColor = Colors.white
      ..indicatorColor = Colors.white
      ..maskColor = Colors.transparent
      ..textStyle = const TextStyle(
        color: Colors.white,
        fontSize: 13,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w600,
      )
      ..radius = 0.0
      ..contentPadding = const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      )
      ..boxShadow = const <BoxShadow>[]
      ..toastPosition = EasyLoadingToastPosition.center
      ..maskType = EasyLoadingMaskType.none
      ..userInteractions = true
      ..dismissOnTap = false
      ..animationStyle = EasyLoadingAnimationStyle.opacity;
  }

  /// Plain text toast.
  static void show(String message, {Duration? duration}) {
    EasyLoading.showToast(
      message,
      duration: duration ?? const Duration(milliseconds: 2000),
      toastPosition: EasyLoadingToastPosition.center,
    );
  }

  /// Semantic alias for a success message — visually identical to [show],
  /// kept as a separate API so call sites read cleanly.
  static void success(String message) => show(message);

  /// Semantic alias for an error message — visually identical to [show].
  static void error(String message) => show(message);

  /// Semantic alias for an informational message — visually identical to
  /// [show].
  static void info(String message) => show(message);

  /// Dismiss any visible toast / loading indicator immediately.
  static void dismiss() => EasyLoading.dismiss();
}
