import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Full-screen square-crop page following the Zeon "Sovereign Skeletalism"
/// design language.
///
/// Push this page and `await` its result to get the cropped [imageBytes]
/// (PNG-encoded, 512 × 512 px), or `null` if the user cancels.
///
/// Usage:
/// ```dart
/// final cropped = await Navigator.push<Uint8List>(
///   context,
///   MaterialPageRoute(builder: (_) => ZeonImageCropPage(imageBytes: raw)),
/// );
/// if (cropped != null) { /* use cropped bytes */ }
/// ```
class ZeonImageCropPage extends StatefulWidget {
  final Uint8List imageBytes;

  const ZeonImageCropPage({super.key, required this.imageBytes});

  @override
  State<ZeonImageCropPage> createState() => _ZeonImageCropPageState();
}

class _ZeonImageCropPageState extends State<ZeonImageCropPage> {
  final _cropKey = GlobalKey();
  final _ctrl = TransformationController();
  bool _confirming = false;

  static const double _cropSize = 300.0;
  static const int _outputPx = 512;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);

    try {
      final boundary =
          _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.of(context).pop();
        return;
      }

      // Capture at a higher pixel ratio so the output is crisp.
      final ratio = _outputPx / _cropSize;
      final uiImage = await boundary.toImage(pixelRatio: ratio);
      final byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.of(context).pop(byteData?.buffer.asUint8List());
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0F),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Color(0xFFC6C6C6),
                        fontSize: 11,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Text(
                    'FRAME AVATAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: _confirming ? null : _confirm,
                    child: _confirming
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'CONFIRM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // ── Hint ──────────────────────────────────────────────────────
            const Text(
              'DRAG · PINCH TO POSITION',
              style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 9,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w600,
              ),
            ),

            // ── Crop viewport ─────────────────────────────────────────────
            Expanded(
              child: Center(
                child: Stack(
                  children: [
                    // Dim outer area
                    Container(color: const Color(0xFF0E0E0F)),

                    // Crop square (captured by RepaintBoundary)
                    Center(
                      child: RepaintBoundary(
                        key: _cropKey,
                        child: ClipRect(
                          child: SizedBox(
                            width: _cropSize,
                            height: _cropSize,
                            child: InteractiveViewer(
                              clipBehavior: Clip.hardEdge,
                              minScale: 0.5,
                              maxScale: 6.0,
                              transformationController: _ctrl,
                              child: Image.memory(
                                widget.imageBytes,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                                gaplessPlayback: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Dim mask around the crop square
                    Center(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _DimMaskPainter(cropSize: _cropSize),
                          size: Size(
                            MediaQuery.of(context).size.width,
                            MediaQuery.of(context).size.height,
                          ),
                        ),
                      ),
                    ),

                    // Crop-frame border + corner accents
                    Center(
                      child: IgnorePointer(
                        child: SizedBox(
                          width: _cropSize,
                          height: _cropSize,
                          child: CustomPaint(
                            painter: _CropFramePainter(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Dim mask: dark overlay with transparent square hole ──────────────────────

class _DimMaskPainter extends CustomPainter {
  final double cropSize;
  const _DimMaskPainter({required this.cropSize});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = cropSize / 2;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(Rect.fromLTRB(cx - half, cy - half, cx + half, cy + half))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = const Color(0xCC0E0E0F),
    );
  }

  @override
  bool shouldRepaint(_DimMaskPainter old) => old.cropSize != cropSize;
}

// ── Crop-frame: 1 px white border + 16 px corner marks ───────────────────────

class _CropFramePainter extends CustomPainter {
  const _CropFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderPaint,
    );

    // Corner accents (L-shaped, 16 px arms, 2 px thick)
    final accentPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;

    const arm = 16.0;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(const Offset(0, arm), const Offset(0, 0), accentPaint);
    canvas.drawLine(const Offset(0, 0), const Offset(arm, 0), accentPaint);
    // Top-right
    canvas.drawLine(Offset(w - arm, 0), Offset(w, 0), accentPaint);
    canvas.drawLine(Offset(w, 0), Offset(w, arm), accentPaint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - arm), Offset(0, h), accentPaint);
    canvas.drawLine(Offset(0, h), Offset(arm, h), accentPaint);
    // Bottom-right
    canvas.drawLine(Offset(w - arm, h), Offset(w, h), accentPaint);
    canvas.drawLine(Offset(w, h), Offset(w, h - arm), accentPaint);
  }

  @override
  bool shouldRepaint(_CropFramePainter _) => false;
}
