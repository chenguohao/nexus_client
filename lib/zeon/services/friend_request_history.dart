import 'package:shared_preferences/shared_preferences.dart';

/// 本地保存"我主动发起过好友请求"的 mxid 集合。
///
/// 仅供"发出的请求"二级页"已确认"分组使用：判断一条 accepted 的好友
/// 是否当初由当前用户主动发起。换设备会丢这份历史，是已知 trade-off。
///
/// 当前用户切换（多账号）时调用 [resetForUser] 切换 key。
class FriendRequestHistoryStore {
  FriendRequestHistoryStore._();
  static final FriendRequestHistoryStore instance =
      FriendRequestHistoryStore._();

  String? _userKey;
  Set<String> _cache = <String>{};
  bool _loaded = false;

  String _keyFor(String mxid) => 'zeon_friend_request_history::$mxid';

  /// 在登录完成、知道当前 matrix user id 后调用。
  /// 如果切换了用户，会重新加载新用户的本地历史；同账号重复调用会跳过。
  Future<void> resetForUser(String? matrixUserId) async {
    if (_userKey == matrixUserId && _loaded) return;
    _userKey = matrixUserId;
    _cache = <String>{};
    _loaded = false;
    if (matrixUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    _cache = (prefs.getStringList(_keyFor(matrixUserId)) ?? const <String>[])
        .toSet();
    _loaded = true;
  }

  bool contains(String mxid) => _cache.contains(mxid);

  /// 同步快照，UI 直接消费。
  Set<String> get snapshot => Set.unmodifiable(_cache);

  /// 在 RequestFriendInteractor 成功后调用，写入本地历史。
  Future<void> add(String mxid) async {
    if (_userKey == null) return;
    if (!_cache.add(mxid)) return;
    await _persist();
  }

  /// 当前用户登出 / 删账号时清理。
  Future<void> clearAll() async {
    if (_userKey == null) return;
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(_userKey!));
  }

  Future<void> _persist() async {
    if (_userKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFor(_userKey!), _cache.toList());
  }
}
