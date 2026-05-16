/// Dio [ProgressCallback] may report an unreliable `total` for streamed uploads.
/// Matrix uploads always send [Content-Length] from our known payload size — use that as denominator so the UI fraction matches bytes actually sent vs payload size.
({int receive, int total}) normalizeMatrixUploadSendProgress({
  required int receive,
  required int totalReported,
  required int knownContentLength,
}) {
  final known = knownContentLength;
  if (known > 0) {
    final clampedReceive = receive.clamp(0, known);
    return (receive: clampedReceive, total: known);
  }
  var total = totalReported;
  if (total <= 0 || total < receive) {
    total = receive > 0 ? receive : 1;
  }
  final clampedReceive = receive.clamp(0, total);
  return (receive: clampedReceive, total: total);
}
