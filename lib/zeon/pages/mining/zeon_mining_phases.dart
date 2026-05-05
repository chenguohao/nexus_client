import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import 'zeon_mining_logic.dart' show StepStatus;
import 'zeon_mining_page.dart';

// ══════════════════════════════════════════════════════════════════════════════
// IDLE PHASE — Progress bar + L-corner hold button
// ══════════════════════════════════════════════════════════════════════════════

class IdlePhaseView extends StatelessWidget {
  final double chargeP;
  final bool isCharging;
  final VoidCallback onOrbDown;
  final VoidCallback onOrbUp;
  final VoidCallback onBack;
  final Animation<double> lAnim;

  const IdlePhaseView({
    super.key,
    required this.chargeP,
    required this.isCharging,
    required this.onOrbDown,
    required this.onOrbUp,
    required this.onBack,
    required this.lAnim,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Top bar
          _TopBar(onBack: onBack),
          // Progress bar section (upper center)
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: _IdleProgressBar(
              progress: chargeP,
              isHolding: isCharging,
            ),
          ),
          // Spacer pushes button toward lower half
          const Spacer(),
          // L-corner hold button (lower center)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: _LCornerButton(
              lAnim: lAnim,
              isHolding: isCharging,
              onHoldStart: onOrbDown,
              onHoldEnd: onOrbUp,
            ),
          ),
          const SizedBox(height: 72),
        ],
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _IdleProgressBar extends StatelessWidget {
  final double progress;
  final bool isHolding;
  const _IdleProgressBar({required this.progress, required this.isHolding});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isHolding ? 'INITIALIZING' : 'HOLD TO INITIALIZE',
              style: const TextStyle(
                color: Color(0x47FFFFFF),
                fontSize: 9,
                letterSpacing: 2.8,
                fontWeight: FontWeight.w500,
              ),
            ),
            AnimatedOpacity(
              opacity: isHolding ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                '$pct%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    width: constraints.maxWidth,
                    height: 1,
                    color: const Color(0x1AFFFFFF),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 16),
                    width: constraints.maxWidth * progress,
                    height: 1,
                    color: Colors.white,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── L-corner button ───────────────────────────────────────────────────────────

class _LCornerButton extends StatelessWidget {
  final Animation<double> lAnim;
  final bool isHolding;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  static const _btnWidth = 220.0;
  static const _btnHeight = 56.0;

  const _LCornerButton({
    required this.lAnim,
    required this.isHolding,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onHoldStart(),
      onTapUp: (_) => onHoldEnd(),
      onTapCancel: onHoldEnd,
      child: AnimatedBuilder(
        animation: lAnim,
        builder: (context, _) {
          return CustomPaint(
            painter: _LCornerPainter(
              gap: lAnim.value,
              buttonWidth: _btnWidth,
              buttonHeight: _btnHeight,
            ),
            child: SizedBox(
              width: _btnWidth + 64,
              height: _btnHeight + 64,
              child: Center(
                child: _LButtonInner(isHolding: isHolding),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LButtonInner extends StatelessWidget {
  final bool isHolding;
  const _LButtonInner({required this.isHolding});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _LCornerButton._btnWidth,
      height: _LCornerButton._btnHeight,
      decoration: BoxDecoration(
        color: isHolding
            ? const Color(0x14FFFFFF)
            : const Color(0x08FFFFFF),
        border: Border.all(
          color: isHolding
              ? const Color(0x33FFFFFF)
              : const Color(0x1AFFFFFF),
          width: 1,
        ),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: isHolding
              ? const Text(
                  'INITIALIZING',
                  key: ValueKey('init'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    letterSpacing: 3.5,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : const Text(
                  'HOLD TO INITIALIZE',
                  key: ValueKey('hold'),
                  style: TextStyle(
                    color: Color(0x8CFFFFFF),
                    fontSize: 11,
                    letterSpacing: 3.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── L-corner painter ──────────────────────────────────────────────────────────

class _LCornerPainter extends CustomPainter {
  final double gap; // 0.0 (hugging) → 1.0 (expanded)
  final double buttonWidth;
  final double buttonHeight;

  static const _lLen = 14.0;
  static const _minGap = 4.0;
  static const _maxGap = 18.0;

  const _LCornerPainter({
    required this.gap,
    required this.buttonWidth,
    required this.buttonHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final currentGap = _minGap + gap * (_maxGap - _minGap);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 + gap * 0.35)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final bw = buttonWidth / 2;
    final bh = buttonHeight / 2;

    final tl = Offset(cx - bw - currentGap, cy - bh - currentGap);
    final tr = Offset(cx + bw + currentGap, cy - bh - currentGap);
    final bl = Offset(cx - bw - currentGap, cy + bh + currentGap);
    final br = Offset(cx + bw + currentGap, cy + bh + currentGap);

    // ┌ top-left
    canvas.drawLine(tl, Offset(tl.dx + _lLen, tl.dy), paint);
    canvas.drawLine(tl, Offset(tl.dx, tl.dy + _lLen), paint);
    // ┐ top-right
    canvas.drawLine(tr, Offset(tr.dx - _lLen, tr.dy), paint);
    canvas.drawLine(tr, Offset(tr.dx, tr.dy + _lLen), paint);
    // └ bottom-left
    canvas.drawLine(bl, Offset(bl.dx + _lLen, bl.dy), paint);
    canvas.drawLine(bl, Offset(bl.dx, bl.dy - _lLen), paint);
    // ┘ bottom-right
    canvas.drawLine(br, Offset(br.dx - _lLen, br.dy), paint);
    canvas.drawLine(br, Offset(br.dx, br.dy - _lLen), paint);
  }

  @override
  bool shouldRepaint(_LCornerPainter old) =>
      old.gap != gap ||
      old.buttonWidth != buttonWidth ||
      old.buttonHeight != buttonHeight;
}

// ══════════════════════════════════════════════════════════════════════════════
// MINING PHASE — Hash stream + step progress
// ══════════════════════════════════════════════════════════════════════════════

class MiningPhaseView extends StatelessWidget {
  final List<MiningStep> steps;
  final int hashAttempts;
  final List<String> hashRows;
  final bool miningComplete;
  final VoidCallback onBack;

  const MiningPhaseView({
    super.key,
    required this.steps,
    required this.hashAttempts,
    required this.hashRows,
    required this.miningComplete,
    required this.onBack,
  });

  String _formatAttempts(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopBar(onBack: onBack),
          // Mining header
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
            child: Row(
              children: [
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white,
                    backgroundColor: Color(0x1FFFFFFF),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SHA-256 MINING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_formatAttempts(hashAttempts)} hashes computed',
                      style: const TextStyle(
                        color: Color(0x47FFFFFF),
                        fontSize: 11,
                        fontFamily: 'monospace',
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Hash list
          Expanded(
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.7, 1],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: hashRows.length,
                reverse: false,
                itemBuilder: (ctx, i) {
                  final isCurrent = i == 0;
                  return Text(
                    hashRows[i],
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      letterSpacing: 1.4,
                      height: 26 / 11,
                      color: isCurrent
                          ? const Color(0xE6FFFFFF)
                          : const Color(0x61FFFFFF),
                    ),
                  );
                },
              ),
            ),
          ),
          // Steps panel
          Container(
            color: const Color(0xFF1C1B1C),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
            child: Column(
              children: List.generate(steps.length, (i) {
                return _StepRow(step: steps[i], index: i);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final MiningStep step;
  final int index;

  const _StepRow({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIcon(status: step.status, index: index),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                    color: switch (step.status) {
                      StepStatus.running => Colors.white,
                      StepStatus.done => const Color(0x47FFFFFF),
                      _ => const Color(0x1AFFFFFF),
                    },
                  ),
                ),
                if (step.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    step.detail!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Color(0x47FFFFFF),
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  final StepStatus status;
  final int index;

  const _StepIcon({required this.status, required this.index});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: switch (status) {
        StepStatus.running => const CircularProgressIndicator(
            strokeWidth: 1,
            color: Colors.white,
            backgroundColor: Color(0x1FFFFFFF),
          ),
        StepStatus.done => const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x14FFFFFF),
              border: Border.fromBorderSide(
                  BorderSide(color: Color(0x80FFFFFF))),
            ),
            child: Center(
              child: Text(
                '✓',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        _ => DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: Center(
              child: Text(
                (index + 1).toString().padLeft(2, '0'),
                style: const TextStyle(
                  color: Color(0x47FFFFFF),
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUCCESS PHASE — Identity card + save button (design/gen_key_card)
// ══════════════════════════════════════════════════════════════════════════════

class SuccessPhaseView extends StatefulWidget {
  final String matrixId;
  final String walletAddress;
  final String uid;
  final String registrationDate;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onBack;

  const SuccessPhaseView({
    super.key,
    required this.matrixId,
    required this.walletAddress,
    required this.uid,
    required this.registrationDate,
    required this.saving,
    required this.onSave,
    required this.onBack,
  });

  @override
  State<SuccessPhaseView> createState() => _SuccessPhaseViewState();
}

class _SuccessPhaseViewState extends State<SuccessPhaseView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeSlide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _shortAddress(String addr) {
    if (addr.length <= 14) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
  }

  /// Returns ":domain" from a Matrix user ID like "@uid:domain", or "" if missing.
  String _domainFromMatrixId(String matrixId) {
    final idx = matrixId.indexOf(':');
    if (idx < 0) return '';
    return matrixId.substring(idx); // includes the leading colon
  }

  Widget _buildFadeSlide({required Widget child, double slideY = 12}) {
    return AnimatedBuilder(
      animation: _fadeSlide,
      builder: (_, c) => Opacity(
        opacity: _fadeSlide.value,
        child: Transform.translate(
          offset: Offset(0, slideY * (1 - _fadeSlide.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top bar (SOVEREIGN style) ──
          _buildFadeSlide(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: const Icon(Icons.menu,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'SOVEREIGN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onBack,
                    child: const Icon(Icons.account_balance_wallet_outlined,
                        color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 2),
          // ── Section label ──
          _buildFadeSlide(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'IDENTIFICATION NODE',
                    style: TextStyle(
                      color: Color(0x80FFFFFF),
                      fontSize: 11,
                      letterSpacing: 3.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(width: 32, height: 1, color: Colors.white),
                ],
              ),
            ),
          ),
          // ── Glass card ──
          _buildFadeSlide(
            slideY: 16,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AspectRatio(
                aspectRatio: 1.586,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x14FFFFFF),
                        Color(0x05FFFFFF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x1AFFFFFF)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Upper half: identity info ──
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'ARCHITECT ID',
                                    style: TextStyle(
                                      color: Color(0x66FFFFFF),
                                      fontSize: 11,
                                      letterSpacing: 3.0,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    widget.registrationDate,
                                    style: const TextStyle(
                                      color: Color(0xCCFFFFFF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '@${widget.uid}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: -0.2,
                                        height: 1.3,
                                      ),
                                    ),
                                    TextSpan(
                                      text: _domainFromMatrixId(widget.matrixId),
                                      style: const TextStyle(
                                        color: Color(0x66FFFFFF),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: -0.2,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _shortAddress(widget.walletAddress)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0x66FFFFFF),
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ── Separator (center of card) ──
                        Container(
                          height: 1,
                          color: const Color(0x0DFFFFFF),
                        ),
                        // ── Lower half: QR code ──
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(3),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: CustomPaint(
                                painter: _QrCodePainter(
                                  data: widget.walletAddress,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(flex: 1),
          // ── Save button ──
          _buildFadeSlide(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: GestureDetector(
                onTap: widget.saving ? null : widget.onSave,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.saving)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF131314),
                          ),
                        )
                      else
                        const Icon(Icons.download,
                            color: Color(0xFF131314), size: 18),
                      const SizedBox(width: 10),
                      Text(
                        widget.saving
                            ? 'SAVING...'
                            : 'SAVE TO GALLERY / 保存到相册',
                        style: const TextStyle(
                          color: Color(0xFF131314),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Footer text ──
          _buildFadeSlide(
            child: const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Text(
                'THIS IDENTITY TOKEN IS CRYPTOGRAPHICALLY SIGNED.\nVERIFICATION REQUIRES LEVEL 2 ARCHITECTURE ACCESS.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0x4DFFFFFF),
                  fontSize: 9.5,
                  letterSpacing: 1.5,
                  height: 1.7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared top bar ─────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0x47FFFFFF),
                size: 16,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Z E O N',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0x47FFFFFF),
                fontSize: 10,
                letterSpacing: 5.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

// ── QR code painter using the `qr` package ────────────────────────────────────

class _QrCodePainter extends CustomPainter {
  final String data;

  _QrCodePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;
    final cellSize = size.width / moduleCount;
    final paint = Paint()..color = const Color(0xFF000000);

    for (int r = 0; r < moduleCount; r++) {
      for (int c = 0; c < moduleCount; c++) {
        if (qrImage.isDark(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH(
                c * cellSize, r * cellSize, cellSize + 0.5, cellSize + 0.5),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrCodePainter old) => old.data != data;
}
