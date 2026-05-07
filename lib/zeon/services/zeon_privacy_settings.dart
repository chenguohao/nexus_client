import 'package:shared_preferences/shared_preferences.dart';

/// 用户隐私偏好，存储于 SharedPreferences，同时维护内存缓存供同步读取。
/// 默认值均与原生 Matrix 客户端行为一致（发已读 / 发 typing / 不截图保护）。
class ZeonPrivacySettings {
  static const _keySendReadReceipts = 'zeon_send_read_receipts';
  static const _keySendTyping = 'zeon_send_typing';
  static const _keyScreenshotProtection = 'zeon_screenshot_protection';

  ZeonPrivacySettings._();
  static final ZeonPrivacySettings instance = ZeonPrivacySettings._();

  // ── 内存缓存（同步访问） ──────────────────────────────────────────────────
  bool _sendReadReceipts = true;
  bool _sendTyping = true;
  bool _screenshotProtection = false;
  bool _loaded = false;

  /// 首次调用会从磁盘加载，之后直接返回缓存值。
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _sendReadReceipts = prefs.getBool(_keySendReadReceipts) ?? true;
    _sendTyping = prefs.getBool(_keySendTyping) ?? true;
    _screenshotProtection = prefs.getBool(_keyScreenshotProtection) ?? false;
    _loaded = true;
  }

  // ── 同步 getter（chat.dart 等热路径使用） ────────────────────────────────
  bool get sendReadReceipts => _sendReadReceipts;
  bool get sendTyping => _sendTyping;
  bool get screenshotProtection => _screenshotProtection;

  // ── 写入（同时更新缓存 + 磁盘） ─────────────────────────────────────────
  Future<void> setSendReadReceipts(bool value) async {
    _sendReadReceipts = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySendReadReceipts, value);
  }

  Future<void> setSendTyping(bool value) async {
    _sendTyping = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySendTyping, value);
  }

  Future<void> setScreenshotProtection(bool value) async {
    _screenshotProtection = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyScreenshotProtection, value);
  }
}
