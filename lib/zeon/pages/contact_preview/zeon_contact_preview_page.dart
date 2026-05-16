import 'package:fluffychat/config/zeon_colors.dart';
import 'package:fluffychat/data/network/contact/friend_request_api.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/domain/usecase/contacts/request_friend_interactor.dart';
import 'package:fluffychat/utils/dialog/twake_dialog.dart';
import 'package:fluffychat/utils/twake_snackbar.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/zeon/zeon_profile_header.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// 「按 ID 加好友」流程中的资料预览页。
///
/// 用户在「新建联系人」对话框输入 Zeon ID 并点确认后，本页负责让用户
/// 在真正发出好友请求之前先看一眼对方的资料（头像 / 昵称 / UID），
/// 避免误加或加错号。只有用户在本页主动点击底部「添加好友」按钮，
/// 才会触发 [RequestFriendInteractor] 写入服务端 pending 记录。
///
/// [awaitingRecipientConfirmation] 为 true 时（例如从「发出的请求」进入）：
/// 仍保持陌生人隐私遮罩（头像模糊、昵称脱敏），底部仅展示不可点的「等待确认」。
///
/// 视觉语言沿用 ZeonProfilePage 的 Sovereign Skeletalism
/// （黑底 + 锐角矩形 + monochrome typography）。
class ZeonContactPreviewPage extends StatefulWidget {
  /// 完整 mxid（如 `@alice123:zeon-im.com`），由调用方在 dialog 里已校验存在。
  final String mxid;

  /// 调用方在 dialog 里已经通过 `getUserProfile` 拿到的展示名，用于首屏直接渲染。
  final String? initialDisplayName;

  /// 调用方在 dialog 里已经拿到的头像 mxc:// URI，用于首屏直接渲染。
  final Uri? initialAvatarUri;

  /// 在 **关闭 bottom sheet 之前** 从仍能访问 `Matrix.of` 的 context 捕获的客户端；
  /// 可避免预览页子树在 FlutterEasyLoading 双层 Overlay 下偶发找不到 Provider。
  final Client? matrixClient;

  /// 请求已发出、等待对方确认：底部不展示「添加好友」，改为禁用态文案。
  final bool awaitingRecipientConfirmation;

  const ZeonContactPreviewPage({
    super.key,
    required this.mxid,
    this.initialDisplayName,
    this.initialAvatarUri,
    this.matrixClient,
    this.awaitingRecipientConfirmation = false,
  });

  @override
  State<ZeonContactPreviewPage> createState() => _ZeonContactPreviewPageState();
}

class _ZeonContactPreviewPageState extends State<ZeonContactPreviewPage> {
  String? _displayName;
  Uri? _avatarUri;
  bool _sending = false;

  Client _matrixClient(BuildContext context) =>
      widget.matrixClient ?? Matrix.of(context).client;

  @override
  void initState() {
    super.initState();
    _displayName = widget.initialDisplayName;
    _avatarUri = widget.initialAvatarUri;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProfile());
  }

  /// 进入页面后再去服务端拉一次最新资料，覆盖 dialog 传过来的快照。
  /// 失败静默，UI 继续用 initial 值，不阻塞用户加好友。
  Future<void> _refreshProfile() async {
    try {
      final client = _matrixClient(context);
      final profile = await client.getUserProfile(widget.mxid);
      if (!mounted) return;
      setState(() {
        _displayName = profile.displayname ?? _displayName;
        _avatarUri = profile.avatarUrl ?? _avatarUri;
      });
    } catch (_) {/* best-effort: dialog 阶段已经验证过 mxid 存在，此处忽略 */}
  }

  Future<void> _onTapAddFriend() async {
    if (_sending) return;
    setState(() => _sending = true);

    final client = _matrixClient(context);
    final result = await TwakeDialog.showFutureLoadingDialogFullScreen<
        ({bool ok, String? error})>(
      future: () async {
        try {
          await getIt.get<RequestFriendInteractor>().execute(
                matrixClient: client,
                mxid: widget.mxid,
                displayName: _displayName,
              );
          return (ok: true, error: null);
        } on FriendRequestApiException catch (e) {
          return (ok: false, error: e.message);
        } catch (e) {
          return (ok: false, error: e.toString());
        }
      },
    );
    if (!mounted) return;
    setState(() => _sending = false);

    final outcome = result.result;
    if (outcome == null || !outcome.ok) {
      TwakeSnackBar.show(
        context,
        outcome?.error ?? '发送好友请求失败',
      );
      return;
    }

    getIt.get<ContactsManager>().refreshTomContacts(client);
    if (mounted) {
      Navigator.of(context).pop();
      TwakeSnackBar.show(context, '好友请求已发送，等待对方确认');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mx = _matrixClient(context);
    return Scaffold(
      backgroundColor: ZeonColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _PreviewAppBar(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        ZeonProfileHeader(
                          avatarUri: _avatarUri,
                          displayName: _displayName ?? '',
                          mxid: widget.mxid,
                          matrixClient: mx,
                          privacyMaskStranger: true,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: widget.awaitingRecipientConfirmation
                  ? const _AddFriendButton(
                      loading: false,
                      onPressed: null,
                      label: '等待确认',
                      subtitle: 'PENDING',
                    )
                  : _AddFriendButton(
                      loading: _sending,
                      onPressed: _sending ? null : _onTapAddFriend,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewAppBar extends StatelessWidget {
  final VoidCallback onBack;

  const _PreviewAppBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: ZeonColors.primary,
            ),
            onPressed: onBack,
            splashRadius: 22,
          ),
          const SizedBox(width: 4),
          const Text(
            'PROFILE',
            style: TextStyle(
              color: ZeonColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 4.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFriendButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;
  final String label;
  final String? subtitle;

  const _AddFriendButton({
    required this.loading,
    required this.onPressed,
    this.label = '添加好友',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: enabled ? ZeonColors.primary : ZeonColors.surfaceContainerHigh,
      borderRadius: BorderRadius.zero,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.zero,
        child: Container(
          height: subtitle == null ? 52 : 60,
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: ZeonColors.onPrimary,
                  ),
                )
              : subtitle == null
                  ? Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color:
                            enabled ? ZeonColors.onPrimary : ZeonColors.outline,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            height: 14 / 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: ZeonColors.outline,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                            color: ZeonColors.outline,
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
