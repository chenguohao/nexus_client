import 'package:flutter/material.dart';

/// Zeon "Sovereign Architect" 主题色板（Dark）。
///
/// 核心原则：
/// - 黑底白字，靠 tonal layering 而非边框做层次
/// - 单色克制，仅 [error] 作为危险信号
/// - 无圆角气泡，sharp / 2-4px 微圆角
///
/// 详细规范见 `Client/design/register_set_profile/DESIGN.md`。
class ZeonColors {
  ZeonColors._();

  // ---- Surface 层级 ----
  static const Color background = Color(0xFF131314);
  static const Color surfaceContainerLowest = Color(0xFF0E0E0F);
  static const Color surfaceContainerLow = Color(0xFF1C1B1C);
  static const Color surfaceContainer = Color(0xFF201F20);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2B);
  static const Color surfaceContainerHighest = Color(0xFF353436);

  // ---- Primary / 文本 ----
  static const Color primary = Color(0xFFFFFFFF);
  static const Color onPrimary = Color(0xFF1A1C1C);
  static const Color onSurface = Color(0xFFE5E2E3);
  static const Color onSurfaceVariant = Color(0xFFC6C6C6);

  // ---- Outline / 分隔 ----
  static const Color outline = Color(0xFF919191);
  static const Color outlineVariant = Color(0xFF474747);

  // ---- 信号 ----
  static const Color error = Color(0xFFFFB4AB);
}
