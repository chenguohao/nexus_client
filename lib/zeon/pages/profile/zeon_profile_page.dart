import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import '../../../pages/settings_dashboard/settings/settings.dart';
import '../../../utils/platform_infos.dart';
import '../../../widgets/matrix.dart';
import '../../../widgets/zeon/zeon_profile_header.dart';
import '../../services/key_service.dart';
import '../../services/zeon_soft_logout.dart';
import '../../utils/toast.dart';
import 'zeon_profile_edit_page.dart';

/// Zeon "我的" / Profile screen.
///
/// Visual language follows `Client/design/profile/screen.png`
/// (Sovereign Skeletalism — dark editorial layout, sharp rectangles,
/// monochrome typography). Content is the Zeon-specific 3-section layout:
///
///   1. Identity     : avatar + nickname + UID
///   2. Web3         : wallet address (only visible to self)
///   3. Settings     : 隐私与安全 / 关于 / 设置 / 登出
///
/// Reachable via the `/rooms/me` route, and rendered as the third tab of
/// the bottom navigation (replacing the legacy "SETTINGS" tab).
class ZeonProfilePage extends StatefulWidget {
  /// Optional bottom navigation widget injected by the adaptive scaffold so
  /// this page can host the shared bottom navigation bar when shown as a tab.
  final Widget? bottomNavigationBar;

  const ZeonProfilePage({super.key, this.bottomNavigationBar});

  @override
  State<ZeonProfilePage> createState() => _ZeonProfilePageState();
}

class _ZeonProfilePageState extends State<ZeonProfilePage> {
  final KeyService _keyService = KeyService();

  Uri? _avatarUri;
  String? _displayName;

  String? _walletAddress;
  bool _walletVisible = false;

  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
      _loadWallet();
    });
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    try {
      final client = Matrix.of(context).client;
      final userId = client.userID;
      if (userId == null) return;
      // After an edit we mark the cached profile as outdated so the SDK
      // refetches from the homeserver instead of returning the stale entry
      // (default cache TTL is 1 day).
      if (forceRefresh) {
        try {
          await client.database.markUserProfileAsOutdated(userId);
        } catch (_) {/* best-effort cache invalidation */}
      }
      final profile = await client.getProfileFromUserId(
        userId,
        getFromRooms: false,
        maxCacheAge: forceRefresh ? Duration.zero : const Duration(days: 1),
      );
      if (!mounted) return;
      setState(() {
        _avatarUri = profile.avatarUrl;
        _displayName = profile.displayName;
      });
    } catch (e) {
      Logs().w('ZeonProfilePage: load profile failed: $e');
    }
  }

  Future<void> _loadWallet() async {
    try {
      final pk = await _keyService.getOrCreatePrivateKey();
      final addr = _keyService.address(pk);
      if (!mounted) return;
      setState(() => _walletAddress = addr);
    } catch (e) {
      Logs().w('ZeonProfilePage: load wallet failed: $e');
    }
  }

  void _copy(String? text, String label) {
    if (text == null || text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    Toast.success('$label 已复制');
  }

  String _maskedAddress(String addr) {
    if (addr.length < 12) return addr;
    final head = addr.substring(0, 6);
    final tail = addr.substring(addr.length - 4);
    return '$head•••••••••••••$tail';
  }

  Future<void> _confirmAndLogout() async {
    if (_loggingOut) return;

    // Use a record to return both the confirmation and the checkbox state.
    final result = await showDialog<(bool confirmed, bool clearData)>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        var clearData = false;
        return StatefulBuilder(
          builder: (ctx, setInnerState) => AlertDialog(
            backgroundColor: const Color(0xFF1C1B1C),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            title: const Text(
              '确认登出',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '登出后，需要使用密钥卡片才能在本设备恢复登录。',
                  style: TextStyle(
                    color: Color(0xFFC6C6C6),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                // Clear data checkbox
                GestureDetector(
                  onTap: () => setInnerState(() => clearData = !clearData),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: Checkbox(
                          value: clearData,
                          onChanged: (v) =>
                              setInnerState(() => clearData = v ?? false),
                          side: const BorderSide(
                            color: Color(0xFF636363),
                            width: 1.5,
                          ),
                          activeColor: const Color(0xFFFFB4AB),
                          checkColor: const Color(0xFF1C1B1C),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '同时清空本地聊天记录',
                        style: TextStyle(
                          color: Color(0xFF919191),
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, (false, false)),
                child: const Text(
                  '取消',
                  style: TextStyle(
                    color: Color(0xFFC6C6C6),
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, (true, clearData)),
                child: const Text(
                  '登出',
                  style: TextStyle(
                    color: Color(0xFFFFB4AB),
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !result.$1) return;
    final clearData = result.$2;

    setState(() => _loggingOut = true);
    try {
      final matrix = Matrix.of(context);
      if (matrix.backgroundPush != null) {
        try {
          await matrix.backgroundPush!.removeCurrentPusher();
        } catch (_) {/* best-effort */}
      }
      if (clearData) {
        // Hard logout: wipe the local Hive database entirely. The next login
        // will start with a clean slate (no message history, no crypto keys).
        await matrix.client.clear();
      }
      // Soft logout: invalidates the server token and sets accessToken = null
      // so isLogged() returns false. If clearData was true, the database is
      // already wiped above; soft logout then becomes a no-op for local data.
      await ZeonSoftLogout.execute(matrix.client);
    } catch (e) {
      Logs().w('ZeonProfilePage: logout failed: $e');
    }
    if (!mounted) return;
    setState(() => _loggingOut = false);
    context.go('/home');
  }

  // ── Section actions ─────────────────────────────────────────────────────

  void _onTapPrivacy() => context.push('/rooms/zeon-privacy');

  void _onTapAbout() => PlatformInfos.showAboutDialogFullScreen();

  void _onTapSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _SettingsHostPage()),
    );
  }

  void _onTapWallet() {
    setState(() => _walletVisible = true);
  }

  void _onTapEdit() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ZeonProfileEditPage(),
      ),
    );
    if (updated == true && mounted) {
      await _loadProfile(forceRefresh: true);
      Toast.success('资料已更新');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      bottomNavigationBar: widget.bottomNavigationBar,
      body: SafeArea(
        child: Stack(
          children: [
            const IgnorePointer(child: _BackgroundGlow()),
            Column(
              children: [
                _TopAppBar(onTapWallet: _onTapWallet, onTapEdit: _onTapEdit),
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
                              mxid: Matrix.of(context).client.userID,
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 36),
                            const _SectionLabel(text: 'WEB3 · 钱包'),
                            const SizedBox(height: 12),
                            _WalletSection(
                              address: _walletAddress,
                              visible: _walletVisible,
                              onToggleVisible: () => setState(
                                () => _walletVisible = !_walletVisible,
                              ),
                              onCopy: () => _copy(_walletAddress, '钱包地址'),
                              maskFn: _maskedAddress,
                            ),
                            const SizedBox(height: 32),
                            const _SectionLabel(text: 'SETTINGS · 设置'),
                            const SizedBox(height: 12),
                            _SettingsListGroup(
                              items: [
                                _SettingItemData(
                                  icon: Icons.shield_outlined,
                                  label: '隐私与安全',
                                  onTap: _onTapPrivacy,
                                ),
                                _SettingItemData(
                                  icon: Icons.info_outline,
                                  label: '关于',
                                  onTap: _onTapAbout,
                                ),
                                _SettingItemData(
                                  icon: Icons.tune,
                                  label: '设置',
                                  onTap: _onTapSettings,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _LogoutCard(
                              onTap: _confirmAndLogout,
                              loading: _loggingOut,
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top app bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopAppBar extends StatelessWidget {
  final VoidCallback onTapWallet;
  final VoidCallback onTapEdit;

  const _TopAppBar({required this.onTapWallet, required this.onTapEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          const Text(
            'ZEON',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 5.4,
            ),
          ),
          const Spacer(),
          _CornerIconButton(
            icon: Icons.edit_square,
            onTap: onTapEdit,
          ),
        ],
      ),
    );
  }
}

class _CornerIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CornerIconButton({required this.icon, required this.onTap});

  @override
  State<_CornerIconButton> createState() => _CornerIconButtonState();
}

class _CornerIconButtonState extends State<_CornerIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section: Web3 wallet
// ─────────────────────────────────────────────────────────────────────────────

class _WalletSection extends StatelessWidget {
  final String? address;
  final bool visible;
  final VoidCallback onToggleVisible;
  final VoidCallback onCopy;
  final String Function(String) maskFn;

  const _WalletSection({
    required this.address,
    required this.visible,
    required this.onToggleVisible,
    required this.onCopy,
    required this.maskFn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1C),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            children: [
              const Text(
                '钱包地址',
                style: TextStyle(
                  color: Color(0xFFC6C6C6),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.4,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2B),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline,
                        size: 11, color: Color(0xFFC6C6C6)),
                    SizedBox(width: 4),
                    Text(
                      '仅自己可见',
                      style: TextStyle(
                        color: Color(0xFFC6C6C6),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Address row
          Row(
            children: [
              Expanded(
                child: Text(
                  _displayedAddress(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: address == null ? null : onToggleVisible,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    visible ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                    color: address == null
                        ? const Color(0xFF474747)
                        : const Color(0xFFC6C6C6),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: address == null ? null : onCopy,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.content_copy,
                    size: 16,
                    color: address == null
                        ? const Color(0xFF474747)
                        : const Color(0xFFC6C6C6),
                  ),
                ),
              ),
            ],
          ),
          Container(height: 1, color: const Color(0x1AFFFFFF)),

        ],
      ),
    );
  }

  String _displayedAddress() {
    if (address == null) return '生成中…';
    return visible ? address! : maskFn(address!);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section: Settings list group
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFC6C6C6),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 3.2,
        ),
      ),
    );
  }
}

class _SettingItemData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingItemData({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _SettingsListGroup extends StatelessWidget {
  final List<_SettingItemData> items;

  const _SettingsListGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      children.add(_SettingsListItem(data: items[i]));
      if (i < items.length - 1) {
        children.add(Container(height: 1, color: const Color(0x14FFFFFF)));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1C),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsListItem extends StatefulWidget {
  final _SettingItemData data;

  const _SettingsListItem({required this.data});

  @override
  State<_SettingsListItem> createState() => _SettingsListItemState();
}

class _SettingsListItemState extends State<_SettingsListItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.data.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hover
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(widget.data.icon,
                  size: 18, color: const Color(0xFFC6C6C6)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.data.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFF919191),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logout (separate, error-color card)
// ─────────────────────────────────────────────────────────────────────────────

class _LogoutCard extends StatefulWidget {
  final VoidCallback onTap;
  final bool loading;

  const _LogoutCard({required this.onTap, required this.loading});

  @override
  State<_LogoutCard> createState() => _LogoutCardState();
}

class _LogoutCardState extends State<_LogoutCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.loading
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hover
                ? const Color(0x33930009)
                : const Color(0xFF1C1B1C),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFFFFB4AB),
                  ),
                )
              else
                const Icon(
                  Icons.logout,
                  size: 16,
                  color: Color(0xFFFFB4AB),
                ),
              const SizedBox(width: 12),
              const Text(
                '登出',
                style: TextStyle(
                  color: Color(0xFFFFB4AB),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
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
// Background glow (consistent with other Zeon Sovereign pages)
// ─────────────────────────────────────────────────────────────────────────────

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 80,
          left: -100,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.025),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          right: -100,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.02),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings host page — wraps the existing Settings widget so it can be pushed
// from the Profile screen with a working back affordance.
//
// `Settings` ships with its own `TwakeAppBar` whose `automaticallyImplyLeading`
// is disabled, which means a plain Navigator push would leave the user with no
// back button. We therefore keep `Settings` rendering its own scaffold and just
// overlay a small floating back chip in the top-left.
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsHostPage extends StatelessWidget {
  const _SettingsHostPage();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Settings(),
        Positioned(
          top: MediaQuery.of(context).padding.top + 6,
          left: 8,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
