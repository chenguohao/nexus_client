import 'dart:typed_data';

import 'package:convert/convert.dart';

/// LSB steganography service for embedding/extracting data in RGBA images.
///
/// Format v2 (variable length):
///   magic "NXKS" (4 bytes) + payload_length (2 bytes big-endian) + payload
class SteganographyService {
  static const _magic = [0x4E, 0x58, 0x4B, 0x53]; // "NXKS"
  static const _headerBytes = 4 + 2; // magic + length

  /// Embed arbitrary [dataHex] (hex string) into RGBA image bytes.
  Uint8List embed(Uint8List rgbaBytes, String dataHex) {
    final dataBytes = hex.decode(dataHex);
    if (dataBytes.length > 65535) {
      throw ArgumentError('Data too large (${dataBytes.length} bytes, max 65535)');
    }
    final payloadLen = _headerBytes + dataBytes.length;
    final payload = Uint8List(payloadLen)
      ..setRange(0, 4, _magic)
      ..[4] = (dataBytes.length >> 8) & 0xFF
      ..[5] = dataBytes.length & 0xFF
      ..setRange(6, 6 + dataBytes.length, dataBytes);

    final bits = _bytesToBits(payload);
    final minPixels = (bits.length / 3).ceil();
    final availablePixels = rgbaBytes.length ~/ 4;
    if (availablePixels < minPixels) {
      throw StateError('Image too small: needs $minPixels pixels, has $availablePixels');
    }

    final out = Uint8List.fromList(rgbaBytes);
    var bitIdx = 0;
    for (var pixelIdx = 0; pixelIdx < availablePixels && bitIdx < bits.length; pixelIdx++) {
      final base = pixelIdx * 4;
      if (bitIdx < bits.length) out[base] = (out[base] & 0xFE) | bits[bitIdx++];
      if (bitIdx < bits.length) out[base + 1] = (out[base + 1] & 0xFE) | bits[bitIdx++];
      if (bitIdx < bits.length) out[base + 2] = (out[base + 2] & 0xFE) | bits[bitIdx++];
    }
    return out;
  }

  /// Extract hex-encoded data from RGBA image bytes.
  String extract(Uint8List rgbaBytes) {
    // First read header to get payload length
    final headerBits = _headerBytes * 8;
    final hdrBits = _extractBits(rgbaBytes, headerBits);
    final hdrBytes = _bitsToBytes(hdrBits);

    for (var i = 0; i < 4; i++) {
      if (hdrBytes[i] != _magic[i]) {
        throw SteganographyException('Magic header mismatch — not a Zeon key card image');
      }
    }
    final dataLen = (hdrBytes[4] << 8) | hdrBytes[5];
    if (dataLen == 0 || dataLen > 65535) {
      throw SteganographyException('Invalid payload length: $dataLen');
    }

    // Now read the full payload
    final totalBits = (_headerBytes + dataLen) * 8;
    final allBits = _extractBits(rgbaBytes, totalBits);
    final allBytes = _bitsToBytes(allBits);
    final dataBytes = allBytes.sublist(_headerBytes, _headerBytes + dataLen);
    return hex.encode(dataBytes);
  }

  List<int> _extractBits(Uint8List rgbaBytes, int totalBits) {
    final bits = <int>[];
    for (var pixelIdx = 0; bits.length < totalBits; pixelIdx++) {
      if (pixelIdx * 4 + 3 >= rgbaBytes.length) {
        throw SteganographyException('Image too small to contain embedded data');
      }
      final base = pixelIdx * 4;
      bits.add(rgbaBytes[base] & 1);
      if (bits.length < totalBits) bits.add(rgbaBytes[base + 1] & 1);
      if (bits.length < totalBits) bits.add(rgbaBytes[base + 2] & 1);
    }
    return bits;
  }

  List<int> _bytesToBits(Uint8List bytes) {
    final bits = <int>[];
    for (final byte in bytes) {
      for (var i = 7; i >= 0; i--) {
        bits.add((byte >> i) & 1);
      }
    }
    return bits;
  }

  Uint8List _bitsToBytes(List<int> bits) {
    final bytes = Uint8List(bits.length ~/ 8);
    for (var i = 0; i < bytes.length; i++) {
      var byte = 0;
      for (var b = 0; b < 8; b++) {
        byte = (byte << 1) | bits[i * 8 + b];
      }
      bytes[i] = byte;
    }
    return bytes;
  }
}

class SteganographyException implements Exception {
  final String message;
  const SteganographyException(this.message);
  @override
  String toString() => 'SteganographyException: $message';
}
