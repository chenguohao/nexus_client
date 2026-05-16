import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// About screen — matches Zeon welcome styling; welcome CTAs are replaced by
/// version / build plates.
class ZeonAboutPage extends StatefulWidget {
  const ZeonAboutPage({super.key});

  @override
  State<ZeonAboutPage> createState() => _ZeonAboutPageState();
}

class _ZeonAboutPageState extends State<ZeonAboutPage> {
  static const _showCenterAxis = true;

  String _version = '—';
  String _buildNumber = '—';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (_) {/* keep placeholders */}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: Stack(
        children: [
          if (_showCenterAxis)
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x1AFFFFFF),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.05),
                                blurRadius: 60,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'ZEON',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 14.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 32,
                                  height: 1,
                                  color: const Color(0x4D919191),
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  'ARCHITECTURAL INTERFACE',
                                  style: TextStyle(
                                    color: Color(0xFF919191),
                                    fontSize: 10,
                                    letterSpacing: 3.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  width: 32,
                                  height: 1,
                                  color: const Color(0x4D919191),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
                  child: Column(
                    children: [
                      _AboutVersionPlate(
                        label: 'VERSION',
                        value: _version,
                      ),
                      const SizedBox(height: 12),
                      _AboutVersionPlate(
                        label: 'BUILD',
                        value: _buildNumber,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 48, 32, 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FooterLink(label: 'PROTOCOL', onTap: () {}),
                          const SizedBox(width: 32),
                          _FooterLink(label: 'SECURITY', onTap: () {}),
                          const SizedBox(width: 32),
                          _FooterLink(label: 'NODES', onTap: () {}),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '© 2025 THE SOVEREIGN ARCHITECT. ALL RIGHTS RESERVED.',
                        style: TextStyle(
                          color: Color(0xFF474747),
                          fontSize: 8,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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

class _AboutVersionPlate extends StatelessWidget {
  final String label;
  final String value;

  const _AboutVersionPlate({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x80474747)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF919191),
              fontSize: 10,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF474747),
          fontSize: 9,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
