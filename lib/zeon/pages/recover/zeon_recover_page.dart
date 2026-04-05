import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/steganography_service.dart';
import '../mining/zeon_mining_logic.dart' show ZeonMiningLogic;

class ZeonRecoverPage extends StatefulWidget {
  const ZeonRecoverPage({super.key});

  @override
  State<ZeonRecoverPage> createState() => _ZeonRecoverPageState();
}

class _ZeonRecoverPageState extends State<ZeonRecoverPage> {
  final _steg = SteganographyService();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRecovery());
  }

  Future<void> _startRecovery() async {
    // Step 1: Pick image from gallery
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      if (mounted) context.go('/home');
      return;
    }

    if (!mounted) return;

    // Step 2: Extract encrypted data via LSB
    String encryptedHex;
    try {
      final imageBytes = await File(file.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) throw Exception('Failed to decode image');

      final rgbaBytes = byteData.buffer.asUint8List();
      encryptedHex = _steg.extract(rgbaBytes);
    } catch (e) {
      if (mounted) {
        await _showResultDialog(
          success: false,
          title: 'INVALID IMAGE',
          message: 'This image does not contain a valid Zeon key card.\n\n$e',
        );
        if (mounted) context.go('/home');
      }
      return;
    }

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

    // Step 4: Decrypt
    try {
      final privateKeyHex =
          ZeonMiningLogic.decryptPrivateKey(encryptedHex, password);

      if (mounted) {
        await _showResultDialog(
          success: true,
          title: 'DECRYPTION SUCCESSFUL',
          message:
              'Private key recovered:\n${privateKeyHex.substring(0, 16)}…${privateKeyHex.substring(privateKeyHex.length - 8)}\n\nLength: ${privateKeyHex.length} hex chars (${privateKeyHex.length ~/ 2} bytes)',
        );
        // DEBUG: stay on page, go back to home
        if (mounted) context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        await _showResultDialog(
          success: false,
          title: 'DECRYPTION FAILED',
          message: 'Wrong password or corrupted data.\n\n$e',
        );
        if (mounted) context.go('/home');
      }
    }
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
