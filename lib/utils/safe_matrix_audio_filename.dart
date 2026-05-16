/// [MatrixFile.name] / event body may contain characters that are valid on
/// Android but break iOS local paths or AVFoundation (e.g. ':' from temp
/// filenames like `...2026-05-16-02:16.m4a`).
String safeMatrixAudioLocalFilename(String matrixFileName) {
  var base = matrixFileName.trim();
  if (base.isEmpty) return 'voice.m4a';
  final segments = base.split(RegExp(r'[/\\]'));
  base = segments.isNotEmpty ? segments.last : base;
  base = base.replaceAll(RegExp(r'[:*?"<>|]'), '_');
  return base.isEmpty ? 'voice.m4a' : base;
}
