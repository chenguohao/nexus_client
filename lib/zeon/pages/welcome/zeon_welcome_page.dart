import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ZeonWelcomePage extends StatelessWidget {
  const ZeonWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: Stack(
        children: [
          // Architectural grid background
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),
          // Vertical center axis
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
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Status bar spacer
                const SizedBox(height: 8),
                // Expand to fill space
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Glow decoration
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
                        const SizedBox(height: 8),
                        // Brand name
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
                        // Separator with tagline
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
                  ),
                ),
                // Bottom action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
                  child: Column(
                    children: [
                      _ZeonButton(
                        label: 'CREATE NEW ACCOUNT',
                        isPrimary: true,
                        onTap: () => context.go('/home/register'),
                      ),
                      const SizedBox(height: 12),
                      _ZeonButton(
                        label: 'RESTORE ACCOUNT',
                        isPrimary: false,
                        onTap: () => context.go('/home/recover'),
                      ),
                    ],
                  ),
                ),
                // Footer links
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

class _ZeonButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ZeonButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_ZeonButton> createState() => _ZeonButtonState();
}

class _ZeonButtonState extends State<_ZeonButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? Colors.white
                : Colors.transparent,
            border: widget.isPrimary
                ? null
                : Border.all(color: const Color(0x80474747)),
          ),
          child: Stack(
            children: [
              if (widget.isPrimary)
                Positioned.fill(
                  child: IgnorePointer(child: _ShimmerOverlay()),
                ),
              Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isPrimary
                        ? const Color(0xFF1A1C1C)
                        : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerOverlay extends StatefulWidget {
  @override
  State<_ShimmerOverlay> createState() => _ShimmerOverlayState();
}

class _ShimmerOverlayState extends State<_ShimmerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(min: 0, max: 1);
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 0.5, 0),
              end: Alignment(_anim.value + 0.5, 0),
              colors: const [
                Colors.transparent,
                Color(0x18FFFFFF),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
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

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x07FFFFFF)
      ..strokeWidth = 1;
    const step = 80.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
