import 'dart:ui';

import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/utils/clipboard.dart';
import 'package:fluffychat/utils/twake_snackbar.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:matrix/matrix.dart';

/// "Sovereign Architect" 风格的个人信息卡（头像 + 昵称 + Zeon UID）。
///
/// **共享组件** — 任何展示 Zeon 用户身份的页面都应优先复用此组件，以保持
/// 视觉一致性。当前的调用方包括：
/// - 个人页（`ZeonProfilePage`）
/// - 联系人详情（`ProfileInfoBodyView` / `ChatProfileInfoAppBar`）
///
/// 视觉语言：
/// - 编辑式左对齐排版，深色 Sovereign 调性
/// - 大方形头像（最大 [avatarSize]，默认 280px，AspectRatio 1:1）
/// - 巨幅左对齐昵称（fontSize 56, w900, letterSpacing -1.4）
/// - UID 短码 pill 徽章（带可选复制按钮）
/// - 可选 [subtitle] 行（如在线状态文本）
///
/// mxid 显示策略：默认隐藏 `@` 前缀和 `:server` 后缀，仅显示 localpart
/// （Zeon 用户的公开短码）。复制时同样只复制 localpart（即 6 位 UID）。
///
/// [privacyMaskStranger]：陌生人隐私视图——头像做高斯模糊，展示昵称取前两个
/// Unicode 字素后接字面量 `***`（内部仍传完整 [displayName]，仅影响绘制）。
class ZeonProfileHeader extends StatelessWidget {
  const ZeonProfileHeader({
    super.key,
    required this.avatarUri,
    required this.displayName,
    required this.mxid,
    this.matrixClient,
    this.privacyMaskStranger = false,
    this.subtitle,
    this.onTapAvatar,
    this.avatarSize = 210,
    this.showCopyMxid = true,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 0),
  });

  /// Matrix avatar mxc:// URI（头像，可空 → 渲染抽象占位）
  final Uri? avatarUri;

  /// 用户昵称
  final String displayName;

  /// 完整 mxid（如 `@alice:zeon.chat`），可空。
  /// 显示时会去掉 `@` 前缀和 `:server` 后缀，仅展示 `alice` 作为 UID。
  final String? mxid;

  /// 拉取头像 MXC 所用的 Matrix 客户端；若在 Overlay 下无法 `Matrix.of(context)`，此处必填。
  final Client? matrixClient;

  /// 非好友隐私模式：模糊头像 + 昵称脱敏（见类注释）。
  final bool privacyMaskStranger;

  /// 可选副标题（如在线状态、备注），渲染在 UID pill 下方。
  final Widget? subtitle;

  /// 头像可点击回调（自己页：换头像；他人页：放大查看）。null 时头像不可点。
  final VoidCallback? onTapAvatar;

  /// 头像方块的最大边长。默认 280；窄屏会自动按可用宽度收缩。
  final double avatarSize;

  /// 是否在 UID pill 上启用「复制完整 mxid」交互
  final bool showCopyMxid;

  /// 整个 header 块的外边距
  final EdgeInsetsGeometry padding;

  /// 提取 mxid 的展示文本（去掉 @ 前缀和 :server 部分）
  static String displayUid(String mxid) {
    final stripped = mxid.startsWith('@') ? mxid.substring(1) : mxid;
    final colonIndex = stripped.indexOf(':');
    return colonIndex < 0 ? stripped : stripped.substring(0, colonIndex);
  }

  /// 陌生人视图下的昵称：前两字素 + 字面量 `***`（trim 后；空则 `——`）。
  static String maskDisplayNameForStranger(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '——';
    final prefix = Characters(t).take(2).toString();
    return '$prefix***';
  }

  @override
  Widget build(BuildContext context) {
    final uidDisplay = (mxid != null && mxid!.isNotEmpty)
        ? displayUid(mxid!)
        : null;
    final shownName = privacyMaskStranger
        ? maskDisplayNameForStranger(displayName)
        : displayName;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ZeonHeroAvatar(
            uri: avatarUri,
            matrixClient: matrixClient,
            privacyBlurAvatar: privacyMaskStranger,
            maxSize: avatarSize,
            onTap: onTapAvatar,
          ),
          const SizedBox(height: 28),
          Text(
            shownName.isEmpty ? '——' : shownName,
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: ZeonColors.primary,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.4,
              height: 1.0,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (uidDisplay != null) ...[
            const SizedBox(height: 14),
            _ZeonUidPill(
              uid: uidDisplay,
              showCopy: showCopyMxid && mxid != null,
              onCopy: showCopyMxid && mxid != null
                  ? () => _copyMxid(context, mxid!)
                  : null,
            ),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            subtitle!,
          ],
        ],
      ),
    );
  }

  void _copyMxid(BuildContext context, String mxid) {
    TwakeClipboard.instance.copyText(displayUid(mxid));
    TwakeSnackBar.show(context, L10n.of(context)!.copiedToClipboard);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero avatar — large square tile, optional drop shadow, abstract placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _ZeonHeroAvatar extends StatelessWidget {
  const _ZeonHeroAvatar({
    required this.uri,
    required this.matrixClient,
    required this.privacyBlurAvatar,
    required this.maxSize,
    required this.onTap,
  });

  final Uri? uri;
  final Client? matrixClient;
  final bool privacyBlurAvatar;
  final double maxSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxSize),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: ZeonColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: ZeonColors.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 32,
                spreadRadius: 1,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildContent(context),
        ),
      ),
    );
    if (onTap == null) return tile;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: tile,
    );
  }

  Widget _buildContent(BuildContext context) {
    if (uri == null) return const ZeonAbstractAvatarPlaceholder();
    Widget img = MxcImage(
      key: Key(uri.toString()),
      matrixClient: matrixClient,
      uri: uri,
      fit: BoxFit.cover,
      cacheKey: uri.toString(),
      animated: true,
      isThumbnail: false,
      placeholder: (_) => const ZeonAbstractAvatarPlaceholder(),
    );
    if (privacyBlurAvatar) {
      // 轻度模糊：sigma 过大整张脸会像牛奶块；6 左右仍能辨认大致轮廓与明暗。
      img = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: img,
      );
    }
    return img;
  }
}

/// Sovereign-style placeholder drawn with overlapping dark polygons +
/// a subtle directional light. Used when the user has not uploaded an
/// avatar yet, to keep the editorial mood consistent with the design.
class ZeonAbstractAvatarPlaceholder extends StatelessWidget {
  const ZeonAbstractAvatarPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF161616), Color(0xFF0B0B0B)],
            ),
          ),
        ),
        const CustomPaint(painter: _AbstractAvatarPainter()),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AbstractAvatarPainter extends CustomPainter {
  const _AbstractAvatarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void poly(List<Offset> points, Color color) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color);
    }

    poly([
      Offset(w * 0.05, h * 0.10),
      Offset(w * 0.85, h * 0.05),
      Offset(w * 0.75, h * 0.70),
      Offset(w * 0.10, h * 0.85),
    ], const Color(0xFF1F1F1F));

    poly([
      Offset(w * 0.45, h * 0.05),
      Offset(w * 0.95, h * 0.20),
      Offset(w * 0.85, h * 0.55),
      Offset(w * 0.50, h * 0.40),
    ], const Color(0xFF2A2A2A));

    poly([
      Offset(w * 0.38, h * 0.55),
      Offset(w * 0.65, h * 0.50),
      Offset(w * 0.55, h * 0.78),
      Offset(w * 0.32, h * 0.72),
    ], const Color(0xFF3A3A3A));

    poly([
      Offset(0, h * 0.70),
      Offset(w * 0.60, h * 0.85),
      Offset(w * 0.40, h),
      Offset(0, h),
    ], const Color(0xFF0E0E0E));

    final edge = Paint()
      ..color = const Color(0xFFD0D0D0).withValues(alpha: 0.18)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.45, h * 0.05),
      Offset(w * 0.50, h * 0.40),
      edge,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// UID pill — left-aligned inline badge
// ─────────────────────────────────────────────────────────────────────────────

class _ZeonUidPill extends StatelessWidget {
  const _ZeonUidPill({
    required this.uid,
    required this.showCopy,
    required this.onCopy,
  });

  final String uid;
  final bool showCopy;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: ZeonColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          borderRadius: BorderRadius.circular(2),
          onTap: showCopy ? onCopy : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: ZeonColors.outlineVariant.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ID',
                  style: TextStyle(
                    color: ZeonColors.outline,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  uid,
                  style: const TextStyle(
                    color: ZeonColors.primary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.4,
                  ),
                ),
                if (showCopy) ...[
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.content_copy,
                    size: 13,
                    color: ZeonColors.outline,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
