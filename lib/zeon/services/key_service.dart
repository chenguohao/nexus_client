import 'dart:developer' as dev;
import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:web3dart/crypto.dart' show keccak256, privateKeyBytesToPublic;
import 'package:web3dart/web3dart.dart';

class KeyService {
  static const _storageKey = 'zeon_private_key';

  final FlutterSecureStorage _storage;

  KeyService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  Future<bool> hasExistingKey() async {
    final existing = await _storage.read(key: _storageKey);
    return existing != null;
  }

  Future<EthPrivateKey> getOrCreatePrivateKey() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null) {
      return EthPrivateKey.fromHex(existing);
    }
    return _generateAndStore();
  }

  Future<EthPrivateKey> importPrivateKey(String privateKeyHex) async {
    await _storage.write(key: _storageKey, value: privateKeyHex);
    return EthPrivateKey.fromHex(privateKeyHex);
  }

  Future<EthPrivateKey> regenerate() => _generateAndStore();

  String publicKeyHex(EthPrivateKey privateKey) {
    final pubKeyBytes = _uncompressedPublicKey(privateKey);
    return hex.encode(pubKeyBytes);
  }

  String address(EthPrivateKey privateKey) => privateKey.address.hexEip55;

  /// Matrix `POST /quick-login` password: first 16 bytes of Keccak256(pubX‖pubY)
  /// as 32 hex chars (pub = 64-byte uncompressed form without 0x04). Matches
  /// [services.DeriveMatrixQuickLoginPassword] on zeon_server for mining registration.
  String matrixQuickLoginPassword(EthPrivateKey privateKey) {
    final pub64 = privateKeyBytesToPublic(privateKey.privateKey);
    final h = keccak256(pub64);
    return hex.encode(h.sublist(0, 16));
  }

  Future<EthPrivateKey> _generateAndStore() async {
    dev.log('[KeyService] Generating new secp256k1 key pair…', name: 'KeyService');
    final key = _generateSecp256k1Key();
    final privHex = hex.encode(key.privateKey);
    await _storage.write(key: _storageKey, value: privHex);
    dev.log('[KeyService] Key stored in SecureStorage', name: 'KeyService');
    return key;
  }

  EthPrivateKey _generateSecp256k1Key() {
    final secureRandom = _buildSecureRandom();
    final keyParams = ECKeyGeneratorParameters(ECCurve_secp256k1());
    final generator = ECKeyGenerator()
      ..init(ParametersWithRandom(keyParams, secureRandom));
    final keyPair = generator.generateKeyPair();
    final privateKey = keyPair.privateKey as ECPrivateKey;
    final privD = privateKey.d!;
    final privBytes = _bigIntToBytes32(privD);
    return EthPrivateKey(privBytes);
  }

  Uint8List _uncompressedPublicKey(EthPrivateKey key) {
    final params = ECCurve_secp256k1();
    final privHex = hex.encode(key.privateKey);
    final privateKeyBig = BigInt.parse(privHex, radix: 16);
    final point = params.G * privateKeyBig;
    if (point == null) throw StateError('EC point multiplication returned null');
    final x = _bigIntToBytes32(point.x!.toBigInteger()!);
    final y = _bigIntToBytes32(point.y!.toBigInteger()!);
    return Uint8List.fromList([0x04, ...x, ...y]);
  }

  SecureRandom _buildSecureRandom() {
    final seed = Uint8List(32);
    final rng = Random.secure();
    for (var i = 0; i < seed.length; i++) {
      seed[i] = rng.nextInt(256);
    }
    return FortunaRandom()..seed(KeyParameter(seed));
  }

  Uint8List _bigIntToBytes32(BigInt value) {
    final hexStr = value.toRadixString(16).padLeft(64, '0');
    final trimmed = hexStr.length > 64 ? hexStr.substring(hexStr.length - 64) : hexStr;
    return Uint8List.fromList(hex.decode(trimmed));
  }
}
