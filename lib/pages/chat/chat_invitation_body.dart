import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/pages/chat/chat_background.dart';
import 'package:fluffychat/pages/chat/events/message_content_mixin.dart';
import 'package:fluffychat/widgets/avatar/avatar.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';

class ChatInvitationBody extends StatelessWidget with MessageContentMixin {
  final ChatController controller;

  const ChatInvitationBody(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const ChatBackground(),
        if (Matrix.of(context).wallpaper != null)
          Image.file(
            Matrix.of(context).wallpaper!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        // 深色半透明遮罩，让卡片在任何壁纸上都清晰可读
        Container(color: Colors.black.withValues(alpha: 0.55)),
        SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(child: _buildInvitationContent(context)),
              const _InvitationBottomBar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationContent(BuildContext context) {
    final name = controller.displayInviterName;
    final avatarUri = controller.inviterAvatarUri;
    final isWide = MediaQuery.of(context).size.width > 600;
    final cardWidth = isWide ? 400.0 : 300.0;
    final avatarSize = isWide ? 140.0 : 242.0;

    return Center(
      child: SizedBox(
        width: cardWidth,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1B1C),
            border: Border.all(color: const Color(0x20FFFFFF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 头部：头像区 ───────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: 24,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0x14FFFFFF)),
                  ),
                ),
                child: Column(
                  children: [
                    Avatar(
                      mxContent: avatarUri,
                      name: name,
                      size: avatarSize,
                      borderRadius: 0,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      L10n.of(context)!.hasInvitedYouToAChat,
                      style: const TextStyle(
                        color: Color(0xFF919191),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // ── 底部：操作按钮 ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _ZeonRejectButton(
                        onReject: () =>
                            controller.onRejectInvitation(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ZeonAcceptButton(
                        onAccept: () => controller.onAcceptInvitation(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accept button — filled white (Zeon 主操作风格)
// ─────────────────────────────────────────────────────────────────────────────

class _ZeonAcceptButton extends StatefulWidget {
  final VoidCallback onAccept;

  const _ZeonAcceptButton({required this.onAccept});

  @override
  State<_ZeonAcceptButton> createState() => _ZeonAcceptButtonState();
}

class _ZeonAcceptButtonState extends State<_ZeonAcceptButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onAccept,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover
                ? const Color(0xFFE0E0E0)
                : Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            L10n.of(context)!.accept,
            style: const TextStyle(
              color: Color(0xFF131314),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reject button — outlined (Zeon 次要操作风格)
// ─────────────────────────────────────────────────────────────────────────────

class _ZeonRejectButton extends StatefulWidget {
  final VoidCallback onReject;

  const _ZeonRejectButton({required this.onReject});

  @override
  State<_ZeonRejectButton> createState() => _ZeonRejectButtonState();
}

class _ZeonRejectButtonState extends State<_ZeonRejectButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onReject,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: const Color(0x40FFFFFF)),
          ),
          child: Text(
            L10n.of(context)!.reject,
            style: const TextStyle(
              color: Color(0xFFC6C6C6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar — 提示信息
// ─────────────────────────────────────────────────────────────────────────────

class InvitationAcceptButton extends StatelessWidget {
  final Function() onAccept;

  const InvitationAcceptButton({required this.onAccept, super.key});

  @override
  Widget build(BuildContext context) {
    return _ZeonAcceptButton(onAccept: onAccept);
  }
}

class InvitationRejectButton extends StatelessWidget {
  final Function() onReject;

  const InvitationRejectButton({required this.onReject, super.key});

  @override
  Widget build(BuildContext context) {
    return _ZeonRejectButton(onReject: onReject);
  }
}

class InvitationBottomBar extends StatelessWidget {
  const InvitationBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InvitationBottomBar();
  }
}

class _InvitationBottomBar extends StatelessWidget {
  const _InvitationBottomBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1B1C),
        border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              size: 16,
              color: Color(0xFF636363),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                L10n.of(context)!.youNeedToAcceptTheInvitation,
                maxLines: 2,
                style: const TextStyle(
                  color: Color(0xFF636363),
                  fontSize: 12,
                  height: 1.5,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
