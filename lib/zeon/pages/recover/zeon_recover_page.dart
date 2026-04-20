import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluffychat/domain/model/tom_server_information.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';

import '../../../widgets/matrix.dart';
import '../../services/api_service.dart';
import '../../services/key_service.dart';
import '../../services/steganography_service.dart';
import '../../services/zeon_key_card_qr_decode.dart';
import '../../services/zeon_matrix_client_database.dart';
import '../mining/zeon_mining_logic.dart' show ZeonMiningLogic;

class ZeonRecoverPage extends StatefulWidget {
  const ZeonRecoverPage({super.key});

  @override
  State<ZeonRecoverPage> createState() => _ZeonRecoverPageState();
}

class _ZeonRecoverPageState extends State<ZeonRecoverPage> {
  final _steg = SteganographyService();
  final _keyService = KeyService();
  final _apiService = ApiService();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRecovery());
  }

  Future<void> _startRecovery() async {
    // Step 1: Pick image from gallery (full quality — LSB payload is fragile).
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (file == null) {
      if (mounted) context.go('/home');
      return;
    }

    if (!mounted) return;

    // Step 2: Encrypted key from LSB and/or QR (QR survives JPEG re-compression).
    final imageBytes = await File(file.path).readAsBytes();

    String? lsbEncryptedHex;
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) throw Exception('Failed to decode image');

      final rgbaBytes = byteData.buffer.asUint8List();
      lsbEncryptedHex = _steg.extract(rgbaBytes);
    } catch (_) {
      lsbEncryptedHex = null;
    }

    final qrEncryptedHex = ZeonKeyCardQrDecode.tryDecodeEncryptedHex(imageBytes);

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
        if (mounted) context.go('/home');
      }
      return;
    }

    final decryptCandidates = <MapEntry<String, String>>[
      if (lsbEncryptedHex != null) MapEntry('lsb', lsbEncryptedHex),
      if (qrEncryptedHex != null &&
          qrEncryptedHex.toLowerCase() != lsbEncryptedHex?.toLowerCase())
        MapEntry('qr', qrEncryptedHex),
    ];

    Logs().i(
      'ZeonRecover: imageSize=${imageBytes.length}B '
      'lsb=${lsbEncryptedHex != null} qr=${qrEncryptedHex != null} '
      'decryptCandidates=${decryptCandidates.map((c) => c.key).join(",")} '
      'hexLens=${decryptCandidates.map((c) => c.value.length).join(",")}',
    );

    if (!mounted) return;

    // Step 3: Ask for password
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const _PasswordInputDialog(),
    );
    if (password == null) {
      if (mounted) context.go('/home');
      return;
    }

    if (!mounted) return;

    // Step 4: Decrypt and login (try LSB payload first, then QR if needed).
    try {
      String privateKeyHex = '';
      Object? decryptError;
      var decryptSource = '';
      for (final c in decryptCandidates) {
        try {
          privateKeyHex = ZeonMiningLogic.decryptPrivateKey(
            c.value,
            password,
          );
          decryptSource = c.key;
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

      Logs().i(
        'ZeonRecover: decrypt OK source=$decryptSource '
        'privKeyHexLen=${privateKeyHex.length} '
        '(password not logged)',
      );

      if (!mounted) return;

      // Import key into secure storage
      final privateKey = await _keyService.importPrivateKey(privateKeyHex);
      final walletAddress = _keyService.address(privateKey);
      final quickLoginUser = walletAddress
          .toLowerCase()
          .replaceAll('0x', '')
          .substring(0, 16);

      final matrixPassword = _keyService.matrixQuickLoginPassword(privateKey);

      Logs().i(
        'ZeonRecover: wallet=${_maskAddr(walletAddress)} '
        'quickLoginUser=$quickLoginUser '
        'matrixPasswordLen=${matrixPassword.length} '
        'apiBase=${_apiService.baseUrl}',
      );

      // Login via Zeon API (password derived from pubkey; matches /submit-mining registration)
      final loginResponse = await _apiService.quickLogin(
        username: quickLoginUser,
        password: matrixPassword,
      );

      Logs().i(
        'ZeonRecover: quickLogin OK matrixUserId=${loginResponse.matrixUserId} '
        'deviceId=${loginResponse.deviceId}',
      );

      if (!mounted) return;

      // Login to Matrix client
      final loginError = await _loginMatrixClient(
        matrixUserId: loginResponse.matrixUserId,
        accessToken: loginResponse.matrixAccessToken,
        deviceId: loginResponse.deviceId,
      );

      if (!mounted) return;

      if (loginError != null) {
        Logs().w('ZeonRecover: Matrix client init failed: $loginError');
        await _showResultDialog(
          success: false,
          title: 'LOGIN FAILED',
          message: loginError,
        );
        if (mounted) context.go('/home');
        return;
      }

      context.go('/rooms');
    } catch (e, st) {
      Logs().w('ZeonRecover: RECOVERY FAILED: $e\n$st');
      if (mounted) {
        await _showResultDialog(
          success: false,
          title: 'RECOVERY FAILED',
          message: 'Wrong password or corrupted data.\n\n$e',
        );
        if (mounted) context.go('/home');
      }
    }
  }

  static String _maskAddr(String addr) {
    final a = addr.startsWith('0x') ? addr : '0x$addr';
    if (a.length <= 14) return a;
    return '${a.substring(0, 8)}…${a.substring(a.length - 6)}';
  }

  Future<String?> _loginMatrixClient({
    required String matrixUserId,
    required String accessToken,
    required String deviceId,
  }) async {
    final client = Matrix.of(context).client;
    final homeserverUri = Uri.parse(
      _apiService.baseUrl.replaceFirst(':8080', ':8008'),
    );
    Logs().i('ZeonRecoverPage: logging in as $matrixUserId to $homeserverUri');

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

    // After Zeon login, Dendrite does not advertise a Twake TOM server in its
    // well-known discovery, so the Dio interceptor base URL stays null and
    // /_twake/* requests fail. The Zeon server (port 8080) implements the
    // /_twake/* endpoints, so register it as the TOM server and persist it.
    final matrixState = Matrix.of(context);
    await matrixState.setUpAndStoreZeonToMServices(
      ToMServerInformation(baseUrl: Uri.parse(_apiService.baseUrl)),
    );

    Logs().i('ZeonRecoverPage: logged in successfully as $matrixUserId');
    return null;
  }

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
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x4D474747)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  success ? Icons.check_circle_outline : Icons.error_outline,
                  color: success
                      ? const Color(0xFF4FFFB0)
                      : const Color(0xFFFFB4AB),
                  size: 36,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color:
                        success ? const Color(0xFF4FFFB0) : const Color(0xFFFFB4AB),
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
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

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF131314),
      body: Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 1.5,
        ),
      ),
    );
  }
}

// ── Password input dialog (same style as key_security_dialog) ───────────────

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
            borderRadius: BorderRadius.circular(8),
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
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1B1C),
                  borderRadius: BorderRadius.circular(4),
                  border: const Border(
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
                          borderRadius: BorderRadius.circular(8),
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
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
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
