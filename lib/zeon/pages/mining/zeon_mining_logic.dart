import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:qr/qr.dart';
import 'package:uuid/uuid.dart';
import 'package:web3dart/crypto.dart' show sign;
import 'package:web3dart/web3dart.dart';

import '../../services/api_service.dart';
import '../../services/key_service.dart';
import '../../services/mining_service.dart';
import '../../services/steganography_service.dart';

typedef StepUpdateCallback = void Function(int stepIndex, StepStatus status, String? detail);
typedef MiningProgressCallback = void Function(int attempts);
typedef CompleteCallback = void Function(
    String matrixId, String walletAddress, String uid, String accessToken, String deviceId);
typedef ErrorCallback = void Function(String error);

enum StepStatus { idle, running, done, error }

class ZeonMiningLogic {
  final KeyService keyService;
  final MiningService miningService;
  final ApiService apiService;

  ZeonMiningLogic({
    required this.keyService,
    required this.miningService,
    required this.apiService,
  });

  EthPrivateKey? _privateKey;
  String? _walletAddress;
  String? _challenge;

  Future<void> runRegistration({
    required StepUpdateCallback onStepUpdate,
    required MiningProgressCallback onMiningProgress,
    required CompleteCallback onComplete,
    required ErrorCallback onError,
  }) async {
    try {
      // Step 0: Key Preparation — always generate a fresh key for new registration
      onStepUpdate(0, StepStatus.running, null);
      _privateKey = await keyService.regenerate();
      _walletAddress = keyService.address(_privateKey!);
      final publicKeyHex = keyService.publicKeyHex(_privateKey!);
      onStepUpdate(0, StepStatus.done, '${_walletAddress!.substring(0, 10)}…new key');

      // Step 1: Fetch Challenge
      onStepUpdate(1, StepStatus.running, null);
      final deviceFp = const Uuid().v4();
      _challenge = await apiService.getChallenge(deviceFp);
      onStepUpdate(1, StepStatus.done, '${_challenge!.substring(0, 12)}…received');

      // Step 2: Proof of Work
      onStepUpdate(2, StepStatus.running, null);
      final miningResult = await miningService.mine(
        _challenge!,
        onProgress: onMiningProgress,
      );
      onStepUpdate(2, StepStatus.done, 'nonce=${miningResult.nonce}  hash=…0000 ✓');

      // Step 3: ECDSA Sign (r + s + v = 65 bytes)
      // web3dart returns v=27/28, go-ethereum SigToPub expects v=0/1
      onStepUpdate(3, StepStatus.running, null);
      final msgBytes = utf8.encode('${_challenge!}${miningResult.nonce}');
      final msgHash = sha256.convert(msgBytes).bytes;
      final sig = sign(Uint8List.fromList(msgHash), _privateKey!.privateKey);
      final rBytes = _bigIntToBytes32(sig.r);
      final sBytes = _bigIntToBytes32(sig.s);
      final recoveryId = sig.v >= 27 ? sig.v - 27 : sig.v;
      final sigHex = hex.encode([...rBytes, ...sBytes, recoveryId]);
      onStepUpdate(3, StepStatus.done, 'sig: ${sigHex.substring(0, 12)}…complete');

      // Step 4: Submit Registration
      onStepUpdate(4, StepStatus.running, null);
      final response = await apiService.submitMining(
        challenge: _challenge!,
        nonce: miningResult.nonce,
        hash: miningResult.hash,
        publicKey: publicKeyHex,
        signature: sigHex,
      );
      onStepUpdate(4, StepStatus.done, 'registered on-chain ✓');

      // Step 5: Save Key Card (visual indicator only — actual save happens on button press)
      onStepUpdate(5, StepStatus.running, null);
      await Future.delayed(const Duration(milliseconds: 600));
      onStepUpdate(5, StepStatus.done, 'key card ready ✓');

      onComplete(
        response.matrixUserId,
        response.walletAddress,
        response.uid,
        response.matrixAccessToken,
        response.deviceId,
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<void> saveKeyCard({
    required String matrixUserId,
    required String walletAddress,
    required String uid,
    required String password,
  }) async {
    if (_privateKey == null) {
      _privateKey = await keyService.getOrCreatePrivateKey();
    }
    final privateKeyHex = hex.encode(_privateKey!.privateKey);
    final encryptedHex = _encryptPrivateKey(privateKeyHex, password);
    await _generateAndSaveCard(
      privateKeyHex: privateKeyHex,
      encryptedKeyHex: encryptedHex,
      walletAddress: walletAddress,
      matrixUserId: matrixUserId,
      uid: uid,
    );
  }

  /// AES-256-CBC encryption with PBKDF2 key derivation.
  /// Output format: hex(salt_16 + iv_16 + ciphertext)
  String _encryptPrivateKey(String privateKeyHex, String password) {
    final rng = math.Random.secure();
    final salt = Uint8List(16);
    final iv = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      salt[i] = rng.nextInt(256);
      iv[i] = rng.nextInt(256);
    }

    // PBKDF2-SHA256, 100k iterations → 32-byte AES key
    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(salt, 100000, 32));
    final aesKey = derivator.process(Uint8List.fromList(utf8.encode(password)));

    // AES-256-CBC encrypt
    final cipher = pc.PaddedBlockCipherImpl(
      pc.PKCS7Padding(),
      pc.CBCBlockCipher(pc.AESEngine()),
    )..init(
        true,
        pc.PaddedBlockCipherParameters(
          pc.ParametersWithIV(pc.KeyParameter(aesKey), iv),
          null,
        ),
      );

    final plainBytes = Uint8List.fromList(hex.decode(privateKeyHex));
    final cipherBytes = cipher.process(plainBytes);

    return hex.encode([...salt, ...iv, ...cipherBytes]);
  }

  /// Decrypt an encrypted private key hex. Returns the plaintext private key hex.
  /// Input format: hex(salt_16 + iv_16 + ciphertext)
  static String decryptPrivateKey(String encryptedHex, String password) {
    final raw = Uint8List.fromList(hex.decode(encryptedHex));
    if (raw.length < 33) {
      throw const FormatException('Encrypted data too short');
    }
    final salt = raw.sublist(0, 16);
    final iv = raw.sublist(16, 32);
    final cipherBytes = raw.sublist(32);

    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(salt, 100000, 32));
    final aesKey = derivator.process(Uint8List.fromList(utf8.encode(password)));

    final cipher = pc.PaddedBlockCipherImpl(
      pc.PKCS7Padding(),
      pc.CBCBlockCipher(pc.AESEngine()),
    )..init(
        false,
        pc.PaddedBlockCipherParameters(
          pc.ParametersWithIV(pc.KeyParameter(aesKey), iv),
          null,
        ),
      );

    final plainBytes = cipher.process(Uint8List.fromList(cipherBytes));
    return hex.encode(plainBytes);
  }

  // ── Card image generation ──────────────────────────────────────────────────
  // 3x scale of the on-screen card for crisp output.
  // On-screen card: ~342dp wide (390 - 24*2), aspect 1.586:1 → ~216dp tall.
  // Pixel output: 1026 x 648.

  static const _s = 3.0; // scale factor
  static const _cardWidth = 342.0 * _s;   // 1026
  static const _cardHeight = 216.0 * _s;  // 648
  static const _pad = 24.0 * _s;          // 72
  static const _qrSize = 64.0 * _s;       // 192
  static const _borderRadius = 8.0 * _s;  // 24
  final _steg = SteganographyService();

  Future<void> _generateAndSaveCard({
    required String privateKeyHex,
    required String encryptedKeyHex,
    required String walletAddress,
    required String matrixUserId,
    required String uid,
  }) async {
    // Extract domain from matrixUserId (e.g. "@uid:domain" → "domain")
    final parts = matrixUserId.split(':');
    final domain = parts.length >= 2 ? parts.sublist(1).join(':') : '';

    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, _cardWidth, _cardHeight));

    _drawCard(canvas, walletAddress, uid, domain, encryptedKeyHex);

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(_cardWidth.toInt(), _cardHeight.toInt());
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw StateError('Failed to get image byte data');

    final rgbaBytes = byteData.buffer.asUint8List();
    final embeddedRgba = _steg.embed(rgbaBytes, encryptedKeyHex);

    final pngBytes = await _rgbaToPng(
        Uint8List.fromList(embeddedRgba),
        _cardWidth.toInt(),
        _cardHeight.toInt());

    await Gal.putImageBytes(
      Uint8List.fromList(pngBytes),
      name: 'zeon_key_card_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  void _drawCard(Canvas canvas, String walletAddress, String uid,
      String domain, String encryptedKeyHex) {
    final size = Size(_cardWidth, _cardHeight);
    final halfH = size.height / 2;

    // ── Background (solid opaque for steganography) ──
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF131314));

    // ── Glass gradient ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(_borderRadius)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x14FFFFFF), Color(0x05FFFFFF)],
        ).createShader(Offset.zero & size),
    );

    // ── Border ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Offset(0.5, 0.5) & Size(size.width - 1, size.height - 1),
        Radius.circular(_borderRadius),
      ),
      Paint()
        ..color = const Color(0x1AFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * _s,
    );

    // ── ARCHITECT ID (top left) ──
    _drawText(canvas, 'ARCHITECT ID',
        offset: Offset(_pad, _pad),
        fontSize: 11 * _s,
        color: const Color(0x66FFFFFF),
        letterSpacing: 3.0 * _s);

    // ── Date (top right) ──
    final ts = DateTime.now();
    final dateStr = '${ts.year}.${_pad2(ts.month)}.${_pad2(ts.day)}';
    final datePainter = _makeTextPainter(dateStr,
        fontSize: 11 * _s,
        color: const Color(0xCCFFFFFF),
        letterSpacing: 2.0 * _s,
        fontWeight: FontWeight.w500);
    datePainter.paint(
        canvas, Offset(size.width - _pad - datePainter.width, _pad));

    // ── UID + domain (主身份标识) ──
    // @uid is white; :domain is dimmer so it doesn't distract but stays readable.
    final uidPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '@$uid',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18 * _s,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2 * _s,
            ),
          ),
          if (domain.isNotEmpty)
            TextSpan(
              text: ':$domain',
              style: TextStyle(
                color: const Color(0x66FFFFFF),
                fontSize: 18 * _s,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.2 * _s,
              ),
            ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _cardWidth - _pad * 2);
    uidPainter.paint(canvas, Offset(_pad, _pad + 16 * _s + 11 * _s));

    // ── Wallet address ──
    String shortAddr = walletAddress;
    if (walletAddress.length > 14) {
      shortAddr =
          '${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 4)}';
    }
    _drawText(canvas, shortAddr.toUpperCase(),
        offset: Offset(_pad, _pad + 16 * _s + 11 * _s + 18 * _s * 1.3 + 6 * _s),
        fontSize: 10.5 * _s,
        color: const Color(0x66FFFFFF),
        monospace: true,
        letterSpacing: 1.5 * _s);

    // ── Center separator ──
    canvas.drawLine(
      Offset(_pad, halfH),
      Offset(size.width - _pad, halfH),
      Paint()
        ..color = const Color(0x0DFFFFFF)
        ..strokeWidth = 1 * _s,
    );

    // ── QR code (bottom right) ──
    final qrLeft = size.width - _pad - _qrSize;
    final qrTop = size.height - _pad - _qrSize;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(qrLeft, qrTop, _qrSize, _qrSize),
        Radius.circular(3 * _s),
      ),
      Paint()..color = Colors.white,
    );
    final qrPad = 4 * _s;
    _drawQrCode(canvas, encryptedKeyHex,
        Rect.fromLTWH(qrLeft + qrPad, qrTop + qrPad,
            _qrSize - qrPad * 2, _qrSize - qrPad * 2));
  }

  void _drawQrCode(Canvas canvas, String data, Rect rect) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;
    final cellSize = rect.width / moduleCount;
    final paint = Paint()..color = const Color(0xFF000000);

    for (int r = 0; r < moduleCount; r++) {
      for (int c = 0; c < moduleCount; c++) {
        if (qrImage.isDark(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH(
              rect.left + c * cellSize,
              rect.top + r * cellSize,
              cellSize + 0.5,
              cellSize + 0.5,
            ),
            paint,
          );
        }
      }
    }
  }

  TextPainter _makeTextPainter(
    String text, {
    required double fontSize,
    Color color = Colors.white,
    bool monospace = false,
    FontWeight fontWeight = FontWeight.normal,
    double letterSpacing = 0,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: monospace ? 'monospace' : null,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _cardWidth - _pad * 2);
  }

  void _drawText(
    Canvas canvas,
    String text, {
    required Offset offset,
    required double fontSize,
    Color color = Colors.white,
    bool monospace = false,
    FontWeight fontWeight = FontWeight.normal,
    double letterSpacing = 0,
  }) {
    _makeTextPainter(text,
            fontSize: fontSize,
            color: color,
            monospace: monospace,
            fontWeight: fontWeight,
            letterSpacing: letterSpacing)
        .paint(canvas, offset);
  }

  Future<Uint8List> _rgbaToPng(
      Uint8List rgbaBytes, int width, int height) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgbaBytes,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final img = await completer.future;
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  List<int> _bigIntToBytes32(BigInt value) {
    final hexStr = value.toRadixString(16).padLeft(64, '0');
    final trimmed =
        hexStr.length > 64 ? hexStr.substring(hexStr.length - 64) : hexStr;
    return hex.decode(trimmed);
  }
}
