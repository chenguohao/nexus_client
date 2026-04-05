import 'dart:isolate';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

class MiningResult {
  final String nonce;
  final String hash;
  const MiningResult({required this.nonce, required this.hash});
}

class MiningProgress {
  final int attempts;
  const MiningProgress(this.attempts);
}

class MiningService {
  Future<MiningResult> mine(
    String challenge, {
    void Function(int attempts)? onProgress,
  }) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(
      _mineInIsolate,
      _MineParams(challenge: challenge, sendPort: receivePort.sendPort),
    );
    await for (final message in receivePort) {
      if (message is MiningProgress) {
        onProgress?.call(message.attempts);
      } else if (message is MiningResult) {
        receivePort.close();
        return message;
      }
    }
    throw StateError('Mining isolate closed without result');
  }
}

class _MineParams {
  final String challenge;
  final SendPort sendPort;
  const _MineParams({required this.challenge, required this.sendPort});
}

void _mineInIsolate(_MineParams params) {
  const progressInterval = 5000;
  var nonce = 0;
  while (true) {
    final input = '${params.challenge}$nonce';
    final hashBytes = sha256.convert(input.codeUnits).bytes;
    final hashHex = hex.encode(Uint8List.fromList(hashBytes));
    if (hashHex.endsWith('0000')) {
      params.sendPort.send(MiningResult(nonce: nonce.toString(), hash: hashHex));
      return;
    }
    nonce++;
    if (nonce % progressInterval == 0) {
      params.sendPort.send(MiningProgress(nonce));
    }
  }
}
