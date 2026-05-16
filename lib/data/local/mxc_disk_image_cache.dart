import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Matrix / MXC 媒体二进制磁盘缓存（按「逻辑键」去重，通常为 mxc URI + 缩略图参数）。
///
/// 项目内 [DatabaseApi.getFile]/storeFile 在 Hive 实现里为空操作，头像与预览此前主要依赖
/// [MxcImageCacheManager] 百级内存 LRU，进程存活期内滚动列表也会重复拉取。
class MxcDiskImageCache {
  MxcDiskImageCache._();
  static final MxcDiskImageCache instance = MxcDiskImageCache._();

  Directory? _rootDir;

  Future<Directory> _root() async {
    final cached = _rootDir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'mxc_media_cache'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _rootDir = dir;
    return dir;
  }

  Future<File> _fileForKey(String logicalKey) async {
    final digest = sha256.convert(utf8.encode(logicalKey)).toString();
    final dir = await _root();
    return File(p.join(dir.path, digest));
  }

  Future<Uint8List?> get(String logicalKey) async {
    try {
      final file = await _fileForKey(logicalKey);
      if (!await file.exists()) return null;
      return file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String logicalKey, Uint8List bytes) async {
    try {
      final file = await _fileForKey(logicalKey);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }
}
