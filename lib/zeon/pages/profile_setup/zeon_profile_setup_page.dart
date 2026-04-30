import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import 'package:mime/mime.dart';

import '../../../widgets/matrix.dart';

/// Profile-setup screen ("Step 03 / Define Persona") shown right after the
/// new-account mining flow finishes and the user is logged into Matrix.
///
/// Behaviour
/// ─────────
/// • "Complete Setup" — uploads the picked avatar (if any) and writes the
///   chosen nickname to the Matrix profile, then navigates to `/rooms`.
/// • "Skip for now" — keeps the platform default identity (Matrix uses the
///   localpart of the user id as displayname and a fallback letter avatar)
///   and navigates straight to `/rooms`.
///
/// The visual language follows `design/register_set_profile/code.html`
/// ("The Sovereign Architect").
class ZeonProfileSetupPage extends StatefulWidget {
  const ZeonProfileSetupPage({super.key});

  @override
  State<ZeonProfileSetupPage> createState() => _ZeonProfileSetupPageState();
}

class _ZeonProfileSetupPageState extends State<ZeonProfileSetupPage> {
  final _imagePicker = ImagePicker();
  final _nicknameCtrl = TextEditingController();
  final _nicknameFocus = FocusNode();

  Uint8List? _avatarBytes;
  String? _avatarFilename;
  String? _avatarMime;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_saving) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _avatarBytes = bytes;
        _avatarFilename = picked.name;
        _avatarMime = picked.mimeType ??
            lookupMimeType(picked.name, headerBytes: bytes) ??
            'image/jpeg';
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not load image: $e');
    }
  }

  Future<void> _completeSetup() async {
    if (_saving) return;
    final nickname = _nicknameCtrl.text.trim();

    // Nothing to do — behave like Skip.
    if (nickname.isEmpty && _avatarBytes == null) {
      _skip();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final client = Matrix.of(context).client;

    try {
      if (_avatarBytes != null) {
        final uri = await client.uploadContent(
          _avatarBytes!,
          filename: _avatarFilename,
          contentType: _avatarMime,
        );
        await client.setProfileField(client.userID!, 'avatar_url', {
          'avatar_url': uri.toString(),
        });
      }
      if (nickname.isNotEmpty) {
        await client.setProfileField(client.userID!, 'displayname', {
          'displayname': nickname,
        });
      }
    } catch (e, st) {
      Logs().w('ZeonProfileSetupPage: profile update failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Failed to save profile: $e';
      });
      return;
    }

    if (!mounted) return;
    context.go('/rooms');
  }

  void _skip() {
    if (_saving) return;
    context.go('/rooms');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      // Avoid the keyboard pushing the layout — let the content scroll.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Sovereign Skeletalism background glow ─────────────────────
            const IgnorePointer(child: _BackgroundGlow()),

            // ── Foreground column: top bar + scrolling content ────────────
            Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                  child: Row(
                    children: [
                      // Identity Setup is reachable only after registration;
                      // the back arrow simply skips (matches the design).
                      _IconButton(
                        icon: Icons.arrow_back,
                        onTap: _skip,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'IDENTITY SETUP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main scrolling content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Architectural header
                            const SizedBox(height: 8),
                            const Center(
                              child: Column(
                                children: [
                                  Text(
                                    'STEP 03',
                                    style: TextStyle(
                                      color: Color(0xFFC6C6C6),
                                      fontSize: 10,
                                      letterSpacing: 3.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'DEFINE PERSONA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      height: 1.05,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 48),

                            // Avatar upload
                            Center(
                              child: _AvatarUploader(
                                bytes: _avatarBytes,
                                onTap: _pickAvatar,
                              ),
                            ),

                            const SizedBox(height: 48),

                            // Nickname input
                            const Text(
                              'NICKNAME',
                              style: TextStyle(
                                color: Color(0xFFC6C6C6),
                                fontSize: 11,
                                letterSpacing: 2.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _NicknameField(
                              controller: _nicknameCtrl,
                              focusNode: _nicknameFocus,
                              enabled: !_saving,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Visible to all institutional architects within the sovereign network.',
                              style: TextStyle(
                                color: Color(0x80C6C6C6),
                                fontSize: 10,
                                height: 1.5,
                                fontWeight: FontWeight.w300,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Structural Integrity card
                            const _StructuralIntegrityCard(),

                            // Error
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFFFB4AB),
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],

                            const SizedBox(height: 40),

                            // Primary action
                            _PrimaryButton(
                              label: 'COMPLETE SETUP',
                              loading: _saving,
                              onTap: _completeSetup,
                            ),
                            const SizedBox(height: 8),
                            // Secondary action
                            _SkipButton(onTap: _skip, enabled: !_saving),
                            const SizedBox(height: 8),
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

// ── Components ──────────────────────────────────────────────────────────────

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 120,
          left: -80,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.025),
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          right: -80,
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

class _IconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _AvatarUploader extends StatelessWidget {
  final Uint8List? bytes;
  final VoidCallback onTap;

  const _AvatarUploader({required this.bytes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 192,
        height: 192,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1B1C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0x4D474747),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (bytes != null)
              Image.memory(
                bytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            else
              Center(
                child: Icon(
                  Icons.person_outline,
                  size: 96,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Color(0xFF131314),
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NicknameField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  const _NicknameField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E0F),
        border: Border(
          bottom: BorderSide(color: Color(0x66474747)),
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        cursorColor: Colors.white,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          LengthLimitingTextInputFormatter(48),
        ],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          letterSpacing: 2.2,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(
          hintText: 'ENTER IDENTIFIER',
          hintStyle: TextStyle(
            color: Color(0x4DC6C6C6),
            fontSize: 14,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }
}

class _StructuralIntegrityCard extends StatelessWidget {
  const _StructuralIntegrityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1B1C),
        border: Border(
          left: BorderSide(color: Color(0xFFD4D4D4), width: 2),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: Color(0xFFD4D4D4),
            size: 18,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STRUCTURAL INTEGRITY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Your identity is encrypted via Zero-Knowledge protocols. '
                  'Only your chosen nickname and avatar will be broadcast to the '
                  'sovereign layer.',
                  style: TextStyle(
                    color: Color(0xFFC6C6C6),
                    fontSize: 11,
                    height: 1.5,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (!widget.loading) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (!widget.loading) {
          setState(() => _pressed = false);
          widget.onTap();
        }
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: widget.loading ? const Color(0xFFD4D4D4) : Colors.white,
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFF131314),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Color(0xFF1A1C1C),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.arrow_forward,
                        color: Color(0xFF1A1C1C),
                        size: 16,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool enabled;

  const _SkipButton({required this.onTap, required this.enabled});

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Text(
            'SKIP FOR NOW',
            style: TextStyle(
              color: widget.enabled
                  ? (_hover ? Colors.white : const Color(0xFFC6C6C6))
                  : const Color(0x80C6C6C6),
              fontSize: 10,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
