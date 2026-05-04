import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/utils/string_extension.dart';
import 'package:fluffychat/widgets/avatar/avatar_style.dart';
import 'package:flutter/material.dart';

/// "Sovereign Architect" 风格的默认头像占位符。
///
/// 当用户没有自定义头像时，显示：
/// - 灰底（[ZeonColors.surfaceContainerHighest]）方形 + 4px 微圆角
/// - 白色 / 加粗的首字母（取自 [name]，最多 2 字符）
/// - 极淡的 1px outline 让它在黑底上有轻微浮起感
///
/// 全应用唯一的默认头像样式，被以下组件复用：
/// - [Avatar]（通用 1对1 头像）
/// - [RoomAvatar]（房间头像）
/// - [SecondaryAvatar]（联系人详情大头像）
/// - [ZeonProfileHeader]（顶部个人信息卡）
class AvatarGradientPlaceholder extends StatelessWidget {
  const AvatarGradientPlaceholder({
    super.key,
    this.name,
    required this.width,
    required this.height,
    required this.fontSize,
    this.borderRadius = BorderRadius.zero,
  });

  /// 用户名/房间名，用于派生展示的首字母。
  final String? name;

  final double width;
  final double height;
  final double fontSize;

  /// 容器圆角。调用方一般传 4px 微圆角，
  /// 与全局 [Avatar._cornerRadius] 保持一致。
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final text = name?.getShortcutNameForAvatar() ?? '@';
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ZeonColors.surfaceContainerHighest,
        borderRadius: borderRadius,
        border: Border.all(
          color: ZeonColors.outlineVariant.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            color: ZeonColors.primary,
            fontFamily: AvatarStyle.fontFamily,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
