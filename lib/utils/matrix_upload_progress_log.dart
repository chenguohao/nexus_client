import 'package:matrix/matrix.dart';

/// Debug logs for Dio [onSendProgress] vs normalized upload fraction.
///
/// Console filter: `MatrixUploadProgress`
class MatrixUploadProgressLogger {
  MatrixUploadProgressLogger({
    required this.txid,
    required this.phase,
    this.stepBytes = 256 * 1024,
  });

  final String txid;
  final String phase;
  final int stepBytes;

  int _lastLoggedReceive = -1;

  void maybeLog({
    required int dioReceive,
    required int dioTotal,
    required ({int receive, int total}) normalized,
  }) {
    final normReceive = normalized.receive;
    final normTotal = normalized.total;
    final complete = normTotal > 0 && normReceive >= normTotal;
    final crossed = _lastLoggedReceive < 0 ||
        complete ||
        (normReceive - _lastLoggedReceive).abs() >= stepBytes;
    if (!crossed) return;
    _lastLoggedReceive = normReceive;
    final pct =
        normTotal > 0 ? (100 * normReceive / normTotal).toStringAsFixed(2) : '?';
    Logs().d(
      '[MatrixUploadProgress] txid=$txid phase=$phase '
      'dio_receive=$dioReceive dio_total=$dioTotal '
      'normalized=$normReceive/$normTotal pct=$pct%',
    );
  }
}
