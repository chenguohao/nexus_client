import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../pages/mining/zeon_mining_logic.dart' show ZeonMiningLogic;
import '../../../widgets/matrix.dart';
import '../../services/api_service.dart';
import '../../services/key_service.dart';
import '../../services/mining_service.dart';
import '../../services/zeon_privacy_settings.dart';
import '../../utils/toast.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Entry widget
// ══════════════════════════════════════════════════════════════════════════════

class ZeonPrivacyPage extends StatefulWidget {
  const ZeonPrivacyPage({super.key});

  @override
  State<ZeonPrivacyPage> createState() => _ZeonPrivacyPageState();
}

class _ZeonPrivacyPageState extends State<ZeonPrivacyPage> {
  // ── Services ──────────────────────────────────────────────────────────────
  final _keyService = KeyService();
  late final ZeonMiningLogic _logic = ZeonMiningLogic(
    keyService: _keyService,
    miningService: MiningService(),
    apiService: ApiService(),
  );

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _sendReadReceipts = true;
  bool _sendTyping = true;
  bool _screenshotProtection = false;
  bool _exporting = false;

  String _walletAddress = '';
  String _matrixUserId = '';
  String _uid = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ZeonPrivacySettings.instance.ensureLoaded();
    final key = await _keyService.getOrCreatePrivateKey();
    if (!mounted) return;
    setState(() {
      _sendReadReceipts = ZeonPrivacySettings.instance.sendReadReceipts;
      _sendTyping = ZeonPrivacySettings.instance.sendTyping;
      _screenshotProtection = ZeonPrivacySettings.instance.screenshotProtection;
      _walletAddress = _keyService.address(key);
      _matrixUserId = Matrix.of(context).client.userID ?? '';
      _uid = _extractUid(_matrixUserId);
    });
  }

  static String _extractUid(String mxid) {
    if (!mxid.startsWith('@')) return mxid;
    return mxid.substring(1).split(':').first;
  }

  // ── Read receipts ─────────────────────────────────────────────────────────
  Future<void> _toggleReadReceipts(bool v) async {
    await ZeonPrivacySettings.instance.setSendReadReceipts(v);
    if (!mounted) return;
    setState(() => _sendReadReceipts = v);
  }

  // ── Typing indicator ──────────────────────────────────────────────────────
  Future<void> _toggleTyping(bool v) async {
    await ZeonPrivacySettings.instance.setSendTyping(v);
    if (!mounted) return;
    setState(() => _sendTyping = v);
  }

  // ── Screenshot protection ─────────────────────────────────────────────────
  static const _windowChannel = MethodChannel('app.zeon/window_manager');

  Future<void> _toggleScreenshotProtection(bool v) async {
    await ZeonPrivacySettings.instance.setScreenshotProtection(v);
    if (Platform.isAndroid) {
      await _windowChannel.invokeMethod('setSecure', {'secure': v});
    }
    if (!mounted) return;
    setState(() => _screenshotProtection = v);
  }

  // ── Key card export ───────────────────────────────────────────────────────
  Future<void> _exportKeyCard({required String title}) async {
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _PasswordDialog(title: title),
    );
    if (password == null || !mounted) return;

    setState(() => _exporting = true);
    try {
      await _logic.saveKeyCard(
        matrixUserId: _matrixUserId,
        walletAddress: _walletAddress,
        uid: _uid,
        password: password,
      );
      if (!mounted) return;
      _showMessage('密钥卡已保存至相册', isError: false);
    } catch (e) {
      if (mounted) _showMessage('保存失败: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Backup mnemonic ───────────────────────────────────────────────────────
  Future<void> _showBackupMnemonic() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const _BackupKeyWarningDialog(),
    );
    if (confirmed != true || !mounted) return;

    final words = await _keyService.getMnemonic();
    if (!mounted) return;

    if (words == null) {
      // Legacy account: no mnemonic stored
      _showMessage(
        '旧版账户不支持助记词备份，请通过"再次导出密钥卡"进行离线备份',
        isError: true,
      );
      return;
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _MnemonicDisplayDialog(words: words),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _showMessage(String msg, {required bool isError}) {
    if (isError) {
      Toast.error(msg);
    } else {
      Toast.success(msg);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _exporting
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 1.5,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      children: [
                        _buildSectionLabel('密钥安全 / KEY SECURITY'),
                        const SizedBox(height: 8),
                        _buildKeyActionItem(
                          icon: Icons.lock_outline,
                          title: '更新密钥卡密码',
                          subtitle: '使用新密码重新生成并保存密钥卡图片',
                          onTap: () => _exportKeyCard(title: '设置新密码'),
                        ),
                        _buildDivider(),
                        _buildKeyActionItem(
                          icon: Icons.key_outlined,
                          title: '备份助记词（24 词）',
                          subtitle: '查看 BIP39 助记词，可导入 MetaMask 等钱包',
                          onTap: _showBackupMnemonic,
                        ),
                        _buildDivider(),
                        _buildKeyActionItem(
                          icon: Icons.image_outlined,
                          title: '再次导出密钥卡',
                          subtitle: '将加密密钥卡重新导出至手机相册',
                          onTap: () => _exportKeyCard(title: '导出密钥卡'),
                        ),
                        const SizedBox(height: 32),
                        _buildSectionLabel('隐私控制 / PRIVACY CONTROLS'),
                        const SizedBox(height: 8),
                        _buildToggleItem(
                          icon: Icons.done_all_outlined,
                          title: '已读回执',
                          subtitle: '关闭后对方无法看到你是否已读消息',
                          value: _sendReadReceipts,
                          onChanged: _toggleReadReceipts,
                        ),
                        _buildDivider(),
                        _buildToggleItem(
                          icon: Icons.edit_outlined,
                          title: '正在输入提示',
                          subtitle: '关闭后输入时不向对方发送 typing 状态',
                          value: _sendTyping,
                          onChanged: _toggleTyping,
                        ),
                        _buildDivider(),
                        _buildToggleItem(
                          icon: Icons.shield_outlined,
                          title: '截图保护',
                          subtitle: Platform.isAndroid
                              ? '在任务切换器中隐藏内容，并禁用截图'
                              : '在任务切换器中模糊 App 内容',
                          value: _screenshotProtection,
                          onChanged: _toggleScreenshotProtection,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'PRIVACY · 隐私与安全',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF666666),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.0,
        ),
      ),
    );
  }

  // ── Action item (tap → dialog) ────────────────────────────────────────────
  Widget _buildKeyActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF888888), size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 11,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF444444),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Toggle item ───────────────────────────────────────────────────────────
  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF888888), size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          _ZeonSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // ── Divider ───────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return const Divider(
      color: Color(0xFF1E1E1F),
      height: 1,
      thickness: 1,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Custom Zeon-style switch
// ══════════════════════════════════════════════════════════════════════════════

class _ZeonSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ZeonSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: value ? Colors.white : const Color(0xFF2A2A2B),
          border: Border.all(
            color: value ? Colors.white : const Color(0xFF444444),
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? const Color(0xFF131314) : const Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Password dialog（更新密钥卡密码 / 导出密钥卡）
// ══════════════════════════════════════════════════════════════════════════════

class _PasswordDialog extends StatefulWidget {
  final String title;
  const _PasswordDialog({required this.title});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _obscurePw = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _pwCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final pw = _pwCtrl.text;
    if (pw.isEmpty) {
      setState(() => _error = '请输入密码');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = '密码至少 6 位');
      return;
    }
    if (pw != _confirmCtrl.text) {
      setState(() => _error = '两次输入不一致');
      return;
    }
    Navigator.pop(context, pw);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E0F),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: const Color(0x4D474747)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '此密码用于加密密钥卡图片',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),
              _buildInput(
                controller: _pwCtrl,
                placeholder: '密码（至少 6 位）',
                obscure: _obscurePw,
                onToggle: () => setState(() => _obscurePw = !_obscurePw),
              ),
              const SizedBox(height: 12),
              _buildInput(
                controller: _confirmCtrl,
                placeholder: '确认密码',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFFB4AB),
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: '取消',
                      primary: false,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogButton(
                      label: '确认',
                      primary: true,
                      onTap: _onConfirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String placeholder,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1B1C),
        borderRadius: BorderRadius.zero,
        border: Border(bottom: BorderSide(color: Color(0x80474747))),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(
            color: Color(0xFF666666),
            fontSize: 12,
            letterSpacing: 0.5,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: InputBorder.none,
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure ? Icons.visibility_off : Icons.visibility,
              color: const Color(0xFF919191),
              size: 18,
            ),
          ),
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Backup key warning dialog
// ══════════════════════════════════════════════════════════════════════════════

class _BackupKeyWarningDialog extends StatelessWidget {
  const _BackupKeyWarningDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E0F),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: const Color(0x4D474747)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber,
                  color: Color(0xFFFFB4AB), size: 32),
              const SizedBox(height: 16),
              const Text(
                '查看私钥',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '私钥是你账户的唯一凭证。\n请确保在安全的私人环境中操作，不要对任何人展示。\n\n泄露私钥将导致账户被永久盗取。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 12,
                  height: 1.6,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: '取消',
                      primary: false,
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogButton(
                      label: '我已了解风险',
                      primary: true,
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Mnemonic display dialog — 24 BIP39 words in a numbered grid
// ══════════════════════════════════════════════════════════════════════════════

class _MnemonicDisplayDialog extends StatelessWidget {
  final List<String> words;
  const _MnemonicDisplayDialog({required this.words});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E0F),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: const Color(0x4D474747)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MNEMONIC · 助记词备份',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '可直接导入 MetaMask 等 EVM 钱包',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              // 4 columns × 6 rows grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.4,
                ),
                itemCount: words.length,
                itemBuilder: (_, i) => Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1B),
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${i + 1}.',
                        style: const TextStyle(
                          color: Color(0xFF555555),
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        words[i],
                        style: const TextStyle(
                          color: Color(0xFFE0E0E0),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '请抄写在纸上保存，不要截图或分享给任何人。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: '复制全部',
                      primary: false,
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: words.join(' ')));
                        Toast.success('助记词已复制到剪贴板');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogButton(
                      label: '已安全保存',
                      primary: true,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared dialog button
// ══════════════════════════════════════════════════════════════════════════════

class _DialogButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: primary ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.zero,
          border: primary
              ? null
              : Border.all(color: const Color(0x33474747)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: primary ? const Color(0xFF131314) : const Color(0xFFC6C6C6),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
