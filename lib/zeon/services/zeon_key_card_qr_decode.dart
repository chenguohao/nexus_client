import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Reads the encrypted key from the QR on a Zeon key card image.
///
/// When the image was re-compressed (e.g. messengers), LSB steganography is
/// destroyed but the QR may still decode thanks to error correction.
class ZeonKeyCardQrDecode {
  ZeonKeyCardQrDecode._();

  /// Returns hex payload if a QR with valid Zeon ciphertext shape is found.
  static String? tryDecodeEncryptedHex(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return null;

    for (final Binarizer binarizer in _binarizersFor(image)) {
      try {
        final bitmap = BinaryBitmap(binarizer);
        final text = QRCodeReader().decode(bitmap).text.trim();
        if (_isPlausibleZeonEncryptedHex(text)) return text;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static Iterable<Binarizer> _binarizersFor(img.Image image) sync* {
    final rgba = image.convert(numChannels: 4);
    final int32 = rgba.getBytes(order: img.ChannelOrder.rgba).buffer.asInt32List();
    final w = image.width;
    final h = image.height;
    final source = RGBLuminanceSource(w, h, int32);
    yield HybridBinarizer(source);
    yield GlobalHistogramBinarizer(source);
    yield HybridBinarizer(InvertedLuminanceSource(source));
    yield GlobalHistogramBinarizer(InvertedLuminanceSource(source));
  }

  /// Zeon format: hex(salt_16 + iv_16 + AES-CBC ciphertext); ciphertext is
  /// PKCS7-padded → length is a positive multiple of 16 bytes.
  static bool _isPlausibleZeonEncryptedHex(String s) {
    if (s.length < 96) return false;
    if (s.length % 2 != 0) return false;
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(s)) return false;
    final rawLen = s.length ~/ 2;
    if (rawLen < 48) return false;
    final cipherLen = rawLen - 32;
    return cipherLen > 0 && cipherLen % 16 == 0;
  }
}
