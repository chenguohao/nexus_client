import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluffychat/domain/model/tom_server_information.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import 'package:web3dart/web3dart.dart';

import '../../../widgets/matrix.dart';
import '../../services/api_service.dart';
import '../../services/key_service.dart';
import '../../services/steganography_service.dart';
import '../../services/zeon_key_card_qr_decode.dart';
import '../../services/zeon_matrix_client_database.dart';
import '../mining/zeon_mining_logic.dart' show ZeonMiningLogic;

// ══════════════════════════════════════════════════════════════════════════════
// Page
// ══════════════════════════════════════════════════════════════════════════════

class ZeonRecoverPage extends StatefulWidget {
  const ZeonRecoverPage({super.key});

  @override
  State<ZeonRecoverPage> createState() => _ZeonRecoverPageState();
}

enum _RecoveryMode { choosing, keyCard, mnemonic, processing }

class _ZeonRecoverPageState extends State<ZeonRecoverPage> {
  final _steg = SteganographyService();
  final _keyService = KeyService();
  final _apiService = ApiService();
  final _imagePicker = ImagePicker();

  _RecoveryMode _mode = _RecoveryMode.choosing;

  // ── Shared login helper ────────────────────────────────────────────────────

  Future<String?> _loginMatrixClient({
    required String matrixUserId,
    required String accessToken,
    required String deviceId,
  }) async {
    final matrixState = Matrix.of(context);
    final homeserverUri = Uri.parse(ApiService.envServerUrl.isNotEmpty
        ? ApiService.envServerUrl
        : _apiService.baseUrl.replaceFirst(':8080', ':8008'));
    Logs().i('ZeonRecoverPage: logging in as $matrixUserId to $homeserverUri');

    // If the account is already loaded and logged in (e.g. user switched away
    // but the session is still alive), just make it active — no re-init needed.
    final existing = matrixState.getClientByUserId(matrixUserId);
    if (existing != null && existing.isLogged()) {
      Logs().i('ZeonRecoverPage: $matrixUserId already logged in, switching');
      await matrixState.setActiveClient(existing);
      return null;
    }

    // Get a per-account client candidate. getLoginClient() wires the
    // LoginState.loggedIn event to _handleAddAnotherAccount automatically,
    // which adds the client to widget.clients and persists its name.
    final client = await matrixState.getLoginClient();

    // Soft logout intentionally keeps the local Hive database. If this client
    // instance was previously used by a different user, wipe it now so the
    // recovering user does not inherit stale rooms/messages.
    // We use MatrixState.clearClientForReinit (not ZeonSoftLogout.ensureCleanForUser)
    // because client.clear() emits loggedOut as a side-effect which would
    // navigate away from this page. clearClientForReinit suppresses that.
    await matrixState.clearClientForReinit(client, matrixUserId);

    try {
      await ZeonMatrixClientDatabase.ensureOpenBeforeInit(client);
    } catch (e, st) {
      Logs().w('ZeonRecoverPage: ensureOpenBeforeInit: $e\n$st');
      return 'Matrix store could not be opened: $e';
    }

    try {
      await client.checkHomeserver(homeserverUri, checkWellKnown: false);
    } catch (e) {
      final msg = 'Homeserver unreachable ($homeserverUri): $e';
      Logs().w('ZeonRecoverPage: $msg');
      return msg;
    }

    try {
      await client.init(
        newToken: accessToken,
        newUserID: matrixUserId,
        newHomeserver: homeserverUri,
        newDeviceID: deviceId.isNotEmpty ? deviceId : null,
        newDeviceName: 'Zeon Android',
        waitForFirstSync: false,
      );
    } catch (e) {
      Logs().w('ZeonRecoverPage: client.init error: $e');
      return 'Matrix login failed: $e';
    }

    if (!client.isLogged()) {
      return 'Login succeeded but client state is not logged-in';
    }

    await matrixState.setUpAndStoreZeonToMServices(
      ToMServerInformation(baseUrl: Uri.parse(_apiService.baseUrl)),
    );

    Logs().i('ZeonRecoverPage: logged in successfully as $matrixUserId');
    return null;
  }

  // ── Shared: lookup + quickLogin + navigate ─────────────────────────────────

  Future<void> _finishRecovery(EthPrivateKey privateKey) async {
    if (!mounted) return;
    final walletAddress = _keyService.address(privateKey);
    final quickLoginUser =
        await _apiService.lookupUid(walletAddress: walletAddress);
    final matrixPassword = _keyService.matrixQuickLoginPassword(privateKey);

    final loginResponse = await _apiService.quickLogin(
      username: quickLoginUser,
      password: matrixPassword,
    );

    if (!mounted) return;

    final loginError = await _loginMatrixClient(
      matrixUserId: loginResponse.matrixUserId,
      accessToken: loginResponse.matrixAccessToken,
      deviceId: loginResponse.deviceId,
    );

    if (!mounted) return;

    if (loginError != null) {
      throw Exception(loginError);
    }
    context.go('/rooms');
  }

  // ── Result dialog ──────────────────────────────────────────────────────────

  Future<void> _showResultDialog({
    required bool success,
    required String title,
    required String message,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
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
                Icon(
                  success ? Icons.check_box : Icons.error_outline,
                  color: success
                      ? const Color(0xFF4FFFB0)
                      : const Color(0xFFFFB4AB),
                  size: 36,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: success
                        ? const Color(0xFF4FFFB0)
                        : const Color(0xFFFFB4AB),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  child: Container(
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.zero,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: Color(0xFF131314),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // KEY CARD recovery flow
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _startKeyCardRecovery() async {
    setState(() => _mode = _RecoveryMode.processing);

    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (file == null) {
      if (mounted) setState(() => _mode = _RecoveryMode.choosing);
      return;
    }

    if (!mounted) return;

    final imageBytes = await File(file.path).readAsBytes();

    String? lsbEncryptedHex;
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) throw Exception('Failed to decode image');
      lsbEncryptedHex = _steg.extract(byteData.buffer.asUint8List());
    } catch (_) {
      lsbEncryptedHex = null;
    }

    final qrEncryptedHex =
        ZeonKeyCardQrDecode.tryDecodeEncryptedHex(imageBytes);

    if (lsbEncryptedHex == null && qrEncryptedHex == null) {
      if (mounted) {
        await _showResultDialog(
          success: false,
          title: 'INVALID IMAGE',
          message:
              'Could not read a Zeon key from this image (hidden data and QR). '
              'Use the original key card photo from your gallery, or a clear '
              'shot where the QR is readable.\n',
        );
        if (mounted) setState(() => _mode = _RecoveryMode.choosing);
      }
      return;
    }

    final decryptCandidates = <MapEntry<String, String>>[
      if (lsbEncryptedHex != null) MapEntry('lsb', lsbEncryptedHex),
      if (qrEncryptedHex != null &&
          qrEncryptedHex.toLowerCase() != lsbEncryptedHex?.toLowerCase())
        MapEntry('qr', qrEncryptedHex),
    ];

    if (!mounted) return;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const _PasswordInputDialog(),
    );
    if (password == null) {
      if (mounted) setState(() => _mode = _RecoveryMode.choosing);
      return;
    }

    if (!mounted) return;

    try {
      String privateKeyHex = '';
      Object? decryptError;
      for (final c in decryptCandidates) {
        try {
          privateKeyHex =
              ZeonMiningLogic.decryptPrivateKey(c.value, password);
          decryptError = null;
          break;
        } catch (e, st) {
          Logs().w('ZeonRecover: decrypt failed source=${c.key}: $e\n$st');
          decryptError = e;
        }
      }
      if (privateKeyHex.isEmpty) {
        throw decryptError ?? Exception('Decryption failed');
      }

      final privateKey = await _keyService.importPrivateKey(privateKeyHex);
      await _finishRecovery(privateKey);
    } catch (e, st) {
      Logs().w('ZeonRecover (key card): FAILED: $e\n$st');
      if (mounted) {
        await _showResultDialog(
          success: false,
          title: 'RECOVERY FAILED',
          message: 'Wrong password or corrupted data.\n\n$e',
        );
        if (mounted) setState(() => _mode = _RecoveryMode.choosing);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MNEMONIC recovery flow
  // ══════════════════════════════════════════════════════════════════════════

  void _startMnemonicRecovery() {
    setState(() => _mode = _RecoveryMode.mnemonic);
  }

  Future<void> _submitMnemonic(List<String> words) async {
    setState(() => _mode = _RecoveryMode.processing);
    try {
      final privateKey = await _keyService.importFromMnemonic(words);
      await _finishRecovery(privateKey);
    } catch (e, st) {
      Logs().w('ZeonRecover (mnemonic): FAILED: $e\n$st');
      if (mounted) {
        await _showResultDialog(
          success: false,
          title: 'RECOVERY FAILED',
          message: 'Invalid mnemonic or account not found.\n\n$e',
        );
        if (mounted) setState(() => _mode = _RecoveryMode.mnemonic);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: SafeArea(
        child: switch (_mode) {
          _RecoveryMode.choosing => _ChoosingView(
              onKeyCard: _startKeyCardRecovery,
              onMnemonic: _startMnemonicRecovery,
              onBack: () => context.go('/home'),
            ),
          _RecoveryMode.mnemonic => _MnemonicInputView(
              onSubmit: _submitMnemonic,
              onBack: () => setState(() => _mode = _RecoveryMode.choosing),
            ),
          _RecoveryMode.keyCard ||
          _RecoveryMode.processing =>
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 1.5,
              ),
            ),
        },
      ),
    );
  }

}

// ══════════════════════════════════════════════════════════════════════════════
// Choice screen
// ══════════════════════════════════════════════════════════════════════════════

class _ChoosingView extends StatelessWidget {
  final VoidCallback onKeyCard;
  final VoidCallback onMnemonic;
  final VoidCallback onBack;

  const _ChoosingView({
    required this.onKeyCard,
    required this.onMnemonic,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Top bar
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
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
              const Text(
                'RECOVER · 账户恢复',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            '选择恢复方式',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 11,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 24),
          _RecoveryOptionCard(
            icon: Icons.image_outlined,
            title: '密钥卡图片',
            subtitle: '从相册选取保存过的 Zeon 密钥卡，输入密码恢复',
            onTap: onKeyCard,
          ),
          const SizedBox(height: 16),
          _RecoveryOptionCard(
            icon: Icons.format_list_numbered_outlined,
            title: '助记词（24 词）',
            subtitle: '输入 BIP39 标准助记词恢复，兼容 MetaMask 等钱包',
            onTap: onMnemonic,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _RecoveryOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RecoveryOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E0F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x33474747)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 11,
                      height: 1.4,
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
}

// ══════════════════════════════════════════════════════════════════════════════
// Mnemonic 24-word input view
// ══════════════════════════════════════════════════════════════════════════════

class _MnemonicInputView extends StatefulWidget {
  final Future<void> Function(List<String> words) onSubmit;
  final VoidCallback onBack;

  const _MnemonicInputView({
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<_MnemonicInputView> createState() => _MnemonicInputViewState();
}

class _MnemonicInputViewState extends State<_MnemonicInputView> {
  final _controllers =
      List.generate(24, (_) => TextEditingController());
  final _focusNodes = List.generate(24, (_) => FocusNode());
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  List<String> get _words =>
      _controllers.map((c) => c.text.trim().toLowerCase()).toList();

  void _onPaste(String text) {
    final parts = text.trim().toLowerCase().split(RegExp(r'\s+'));
    if (parts.length == 24) {
      for (var i = 0; i < 24; i++) {
        _controllers[i].text = parts[i];
      }
      setState(() => _error = null);
    }
  }

  Future<void> _onConfirm() async {
    final words = _words;
    if (words.any((w) => w.isEmpty)) {
      setState(() => _error = '请填写全部 24 个助记词');
      return;
    }
    setState(() => _error = null);
    await widget.onSubmit(words);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Top bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
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
              const Text(
                '输入助记词',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.5,
                ),
              ),
              const Spacer(),
              // Paste all button
              GestureDetector(
                onTap: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) _onPaste(data!.text!);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: const Text(
                    '粘贴',
                    style: TextStyle(
                      color: Color(0xFFCCCCCC),
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '按顺序输入 24 个助记词，或点击「粘贴」一键导入',
            style: TextStyle(
              color: Color(0xFF555555),
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 24 word grid — 3 columns
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: 24,
              itemBuilder: (_, i) => _WordCell(
                index: i,
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                nextFocusNode:
                    i < 23 ? _focusNodes[i + 1] : null,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFFFB4AB),
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: GestureDetector(
            onTap: _onConfirm,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text(
                '恢复账户',
                style: TextStyle(
                  color: Color(0xFF131314),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WordCell extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final ValueChanged<String> onChanged;

  const _WordCell({
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.nextFocusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0F),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: const Color(0x33474747)),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction:
            nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          prefix: Text(
            '${index + 1}.',
            style: const TextStyle(
              color: Color(0xFF555555),
              fontSize: 9,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          border: InputBorder.none,
        ),
        onChanged: onChanged,
        onSubmitted: (_) {
          if (nextFocusNode != null) {
            FocusScope.of(context).requestFocus(nextFocusNode);
          }
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Password input dialog (key card recovery)
// ══════════════════════════════════════════════════════════════════════════════

class _PasswordInputDialog extends StatefulWidget {
  const _PasswordInputDialog();

  @override
  State<_PasswordInputDialog> createState() => _PasswordInputDialogState();
}

class _PasswordInputDialogState extends State<_PasswordInputDialog> {
  final _pwCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  void _onConfirm() {
    if (_pwCtrl.text.isEmpty) return;
    Navigator.pop(context, _pwCtrl.text);
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
              const Text(
                'ENTER PASSWORD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the password you set when saving the key card',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0x80FFFFFF),
                  fontSize: 10,
                  letterSpacing: 0.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1B1C),
                  borderRadius: BorderRadius.zero,
                  border: Border(
                    bottom: BorderSide(color: Color(0x80474747)),
                  ),
                ),
                child: TextField(
                  controller: _pwCtrl,
                  obscureText: _obscure,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'PASSWORD',
                    hintStyle: const TextStyle(
                      color: Color(0xFFC6C6C6),
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    border: InputBorder.none,
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF919191),
                        size: 18,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _onConfirm(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.zero,
                          border: Border.all(color: const Color(0x33474747)),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            color: Color(0xFFC6C6C6),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _onConfirm,
                      child: Container(
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.zero,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'CONFIRM',
                          style: TextStyle(
                            color: Color(0xFF131314),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
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
      ),
    );
  }
}
