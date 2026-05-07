import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wallet/wallet.dart' as w;
import 'package:web3dart/crypto.dart' show keccak256, privateKeyBytesToPublic;
import 'package:web3dart/web3dart.dart';

/// Manages the user's secp256k1 private key.
///
/// Storage layout (FlutterSecureStorage):
///   NEW  key = 'zeon_mnemonic'     → space-separated BIP39 24-word phrase
///   OLD  key = 'zeon_private_key'  → 32-byte hex (legacy, read-only fallback)
///
/// Private key is always derived on demand via BIP32 path m/44'/60'/0'/0/0,
/// making it compatible with MetaMask and any EVM HD wallet.
class KeyService {
  static const _storageKey = 'zeon_private_key'; // legacy — do not write
  static const _mnemonicKey = 'zeon_mnemonic'; // canonical
  static const _derivationPath = "m/44'/60'/0'/0/0";

  final FlutterSecureStorage _storage;

  KeyService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions:
              IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  // ── Key existence ──────────────────────────────────────────────────────────

  Future<bool> hasExistingKey() async {
    if (await _storage.read(key: _mnemonicKey) != null) return true;
    return await _storage.read(key: _storageKey) != null;
  }

  // ── Mnemonic access ────────────────────────────────────────────────────────

  /// Returns the stored BIP39 mnemonic words, or null for legacy accounts
  /// (those created before the BIP39 upgrade).
  Future<List<String>?> getMnemonic() async {
    final stored = await _storage.read(key: _mnemonicKey);
    if (stored == null || stored.trim().isEmpty) return null;
    return stored.trim().split(' ');
  }

  // ── Private key derivation ─────────────────────────────────────────────────

  /// Derives EthPrivateKey from BIP39 words via BIP32 m/44'/60'/0'/0/0.
  EthPrivateKey _deriveFromWords(List<String> words) {
    final seed = w.mnemonicToSeed(words);
    final master = w.ExtendedPrivateKey.master(seed, w.xprv);
    final child =
        master.forPath(_derivationPath) as w.ExtendedPrivateKey;
    return EthPrivateKey(_bigIntToBytes32(child.key));
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  /// Returns the current private key. Creates a new BIP39 account if none
  /// exists yet.
  Future<EthPrivateKey> getOrCreatePrivateKey() async {
    // 1. New format: BIP39 mnemonic
    final mnemonicStr = await _storage.read(key: _mnemonicKey);
    if (mnemonicStr != null && mnemonicStr.trim().isNotEmpty) {
      return _deriveFromWords(mnemonicStr.trim().split(' '));
    }
    // 2. Legacy format: raw hex private key (read-only fallback)
    final legacy = await _storage.read(key: _storageKey);
    if (legacy != null && legacy.isNotEmpty) {
      return EthPrivateKey.fromHex(legacy);
    }
    // 3. First run: generate a new BIP39 account
    return regenerate();
  }

  /// Generates a fresh BIP39 24-word mnemonic, stores it, and returns the
  /// derived EthPrivateKey. Any existing key (mnemonic or legacy) is replaced.
  Future<EthPrivateKey> regenerate() async {
    dev.log(
      '[KeyService] Generating new BIP39 mnemonic (24 words)…',
      name: 'KeyService',
    );
    final words = w.generateMnemonic(strength: 256); // 256-bit = 24 words
    await _storage.write(key: _mnemonicKey, value: words.join(' '));
    await _storage.delete(key: _storageKey); // remove legacy if present
    dev.log('[KeyService] Mnemonic stored in SecureStorage', name: 'KeyService');
    return _deriveFromWords(words);
  }

  /// Imports a legacy raw private-key hex (key-card recovery path).
  /// NOTE: This stores the old-format key. The account will show as "legacy"
  /// in getMnemonic().
  Future<EthPrivateKey> importPrivateKey(String privateKeyHex) async {
    await _storage.write(key: _storageKey, value: privateKeyHex);
    await _storage.delete(key: _mnemonicKey);
    return EthPrivateKey.fromHex(privateKeyHex);
  }

  /// Validates and imports a BIP39 mnemonic. Throws [ArgumentError] if the
  /// mnemonic is invalid.
  Future<EthPrivateKey> importFromMnemonic(List<String> words) async {
    if (!w.validateMnemonic(words)) {
      throw ArgumentError('Invalid BIP39 mnemonic');
    }
    await _storage.write(key: _mnemonicKey, value: words.join(' '));
    await _storage.delete(key: _storageKey);
    dev.log(
      '[KeyService] Mnemonic imported into SecureStorage',
      name: 'KeyService',
    );
    return _deriveFromWords(words);
  }

  // ── Public helpers ─────────────────────────────────────────────────────────

  String publicKeyHex(EthPrivateKey privateKey) =>
      hex.encode(_uncompressedPublicKey(privateKey));

  String address(EthPrivateKey privateKey) => privateKey.address.hexEip55;

  /// Matrix `POST /quick-login` password: first 16 bytes of Keccak256(pubX‖pubY).
  String matrixQuickLoginPassword(EthPrivateKey privateKey) {
    final pub64 = privateKeyBytesToPublic(privateKey.privateKey);
    final h = keccak256(pub64);
    return hex.encode(h.sublist(0, 16));
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Uint8List _uncompressedPublicKey(EthPrivateKey key) {
    // privateKeyBytesToPublic returns 64-byte uncompressed XY (no 0x04 prefix)
    final pub64 = privateKeyBytesToPublic(key.privateKey);
    return Uint8List.fromList([0x04, ...pub64]);
  }

  Uint8List _bigIntToBytes32(BigInt value) {
    final hexStr = value.toRadixString(16).padLeft(64, '0');
    final trimmed =
        hexStr.length > 64 ? hexStr.substring(hexStr.length - 64) : hexStr;
    return Uint8List.fromList(hex.decode(trimmed));
  }
}
