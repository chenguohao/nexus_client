import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';

import '../../../widgets/matrix.dart';
import '../../utils/toast.dart';
import '../../widgets/zeon_image_crop_page.dart';

/// Zeon profile-edit screen — lets the current user update their avatar
/// and/or display name.
class ZeonProfileEditPage extends StatefulWidget {
  const ZeonProfileEditPage({super.key});

  @override
  State<ZeonProfileEditPage> createState() => _ZeonProfileEditPageState();
}

class _ZeonProfileEditPageState extends State<ZeonProfileEditPage> {
  final _picker = ImagePicker();
  final _nameCtrl = TextEditingController();

  Uri? _existingAvatarUri;
  Uint8List? _newAvatarBytes;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final client = Matrix.of(context).client;
      final uid = client.userID;
      if (uid == null) return;
      final profile =
          await client.getProfileFromUserId(uid, getFromRooms: false);
      if (!mounted) return;
      setState(() {
        _existingAvatarUri = profile.avatarUrl;
        _nameCtrl.text = profile.displayName ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAndCropAvatar() async {
    if (_saving) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (picked == null || !mounted) return;

      final rawBytes = await picked.readAsBytes();
      if (!mounted) return;

      final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ZeonImageCropPage(imageBytes: rawBytes),
        ),
      );
      if (cropped == null || !mounted) return;

      setState(() {
        _newAvatarBytes = cropped;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '图片加载失败: $e');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty && _newAvatarBytes == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final client = Matrix.of(context).client;
    final uid = client.userID;
    if (uid == null) {
      setState(() => _saving = false);
      return;
    }

    try {
      if (_newAvatarBytes != null) {
        final uri = await client.uploadContent(
          _newAvatarBytes!,
          filename: 'avatar.png',
          contentType: 'image/png',
        );
        await client.setProfileField(uid, 'avatar_url', {
          'avatar_url': uri.toString(),
        });
      }
      if (name.isNotEmpty) {
        await client.setProfileField(uid, 'displayname', {
          'displayname': name,
        });
      }
      // Invalidate the local profile cache so subsequent reads on this page
      // (and the parent profile page) hit the homeserver instead of returning
      // the stale entry — SDK default cache TTL is 1 day.
      try {
        await client.database.markUserProfileAsOutdated(uid);
      } catch (_) {/* best-effort */}
    } catch (e, st) {
      Logs().w('ZeonProfileEditPage: save failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：${e.toString().split('\n').first}';
      });
      Toast.error('保存失败');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true); // true = profile updated
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ─────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  _IconBtn(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'EDIT PROFILE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            if (_loading)
              const Expanded(
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),

                      // ── Avatar ────────────────────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: _pickAndCropAvatar,
                          child: _AvatarPicker(
                            newBytes: _newAvatarBytes,
                            existingUri: _existingAvatarUri,
                            client: Matrix.of(context).client,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── Name ──────────────────────────────────────────
                      const Text(
                        'DISPLAY NAME',
                        style: TextStyle(
                          color: Color(0xFFC6C6C6),
                          fontSize: 10,
                          letterSpacing: 2.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF0E0E0F),
                          border: Border(
                            bottom: BorderSide(color: Color(0x66474747)),
                          ),
                        ),
                        child: TextField(
                          controller: _nameCtrl,
                          enabled: !_saving,
                          cursorColor: Colors.white,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(48),
                          ],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            letterSpacing: 1.4,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'ENTER NAME',
                            hintStyle: TextStyle(
                              color: Color(0x4DC6C6C6),
                              fontSize: 14,
                              letterSpacing: 1.4,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),

                      // ── Error ─────────────────────────────────────────
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFFFB4AB),
                            fontSize: 11,
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),

                      // ── Save button ───────────────────────────────────
                      GestureDetector(
                        onTap: _saving ? null : _save,
                        child: Container(
                          height: 52,
                          color: _saving
                              ? const Color(0xFFD4D4D4)
                              : Colors.white,
                          alignment: Alignment.center,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Color(0xFF131314),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'SAVE CHANGES',
                                      style: TextStyle(
                                        color: Color(0xFF131314),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2.4,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: Color(0xFF131314),
                                      size: 15,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar picker widget ─────────────────────────────────────────────────────

class _AvatarPicker extends StatelessWidget {
  final Uint8List? newBytes;
  final Uri? existingUri;
  final Client client;

  const _AvatarPicker({
    required this.newBytes,
    required this.existingUri,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1B1C),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: const Color(0x4D474747)),
          ),
          clipBehavior: Clip.hardEdge,
          child: _avatarContent(),
        ),
        // Edit badge
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 32,
            height: 32,
            color: Colors.white,
            child: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF131314),
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarContent() {
    if (newBytes != null) {
      return Image.memory(newBytes!, fit: BoxFit.cover);
    }
    if (existingUri != null) {
      final httpUri = existingUri!.getDownloadLink(client);
      return Image.network(
        httpUri.toString(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return const Center(
      child: Icon(
        Icons.person_outline,
        size: 52,
        color: Color(0x33FFFFFF),
      ),
    );
  }
}

// ── Small icon button ────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
