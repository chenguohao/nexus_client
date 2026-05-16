import 'dart:convert';

import 'package:fluffychat/domain/app_state/contact/get_contacts_state.dart';
import 'package:fluffychat/domain/model/contact/contact.dart';
import 'package:fluffychat/domain/model/contact/friend_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tom 通讯录快照持久化：好友状态图 + 联系人列表（供冷启动与刷新过渡期直接使用）。
class TomFriendStatusCache {
  TomFriendStatusCache._();
  static final TomFriendStatusCache instance = TomFriendStatusCache._();

  static String _prefsKey(String matrixUserId) =>
      'zeon_tom_friend_map_v1::$matrixUserId';

  FriendStatus _parseStatus(String raw) => FriendStatus.fromString(raw);

  Map<String, dynamic> _contactToMap(Contact c) {
    return {
      'id': c.id,
      'displayName': c.displayName,
      'friendStatus': c.friendStatus.rawValue,
      'updatedAtMillis': c.updatedAtMillis,
      'emails': c.emails
          ?.map(
            (e) => {
              'address': e.address,
              'matrixId': e.matrixId,
            },
          )
          .toList(),
      'phoneNumbers': c.phoneNumbers
          ?.map(
            (p) => {
              'number': p.number,
              'matrixId': p.matrixId,
            },
          )
          .toList(),
    };
  }

  Contact? _contactFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    try {
      final emailsRaw = m['emails'] as List?;
      Set<Email>? emails;
      if (emailsRaw != null) {
        emails = emailsRaw.map((e) {
          final em = Map<String, dynamic>.from(e as Map);
          return Email(
            address: em['address'] as String,
            matrixId: em['matrixId'] as String?,
          );
        }).toSet();
      }
      final phonesRaw = m['phoneNumbers'] as List?;
      Set<PhoneNumber>? phones;
      if (phonesRaw != null) {
        phones = phonesRaw.map((p) {
          final pm = Map<String, dynamic>.from(p as Map);
          return PhoneNumber(
            number: pm['number'] as String,
            matrixId: pm['matrixId'] as String?,
          );
        }).toSet();
      }
      return Contact(
        id: m['id'] as String,
        displayName: m['displayName'] as String?,
        emails: emails,
        phoneNumbers: phones,
        friendStatus: FriendStatus.fromString(m['friendStatus'] as String?),
        updatedAtMillis: (m['updatedAtMillis'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String matrixUserId, GetContactsSuccess success) async {
    if (matrixUserId.isEmpty) return;
    final friendMap = <String, String>{};
    success.friendStatusByMxid.forEach((mxid, st) {
      friendMap[mxid] = st.rawValue;
    });
    final payload = <String, dynamic>{
      'v': 2,
      'friendStatusByMxid': friendMap,
      'contacts': success.contacts.map(_contactToMap).toList(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(matrixUserId), jsonEncode(payload));
  }

  Future<GetContactsSuccess?> load(String matrixUserId) async {
    if (matrixUserId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(matrixUserId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['contacts'] is List) {
        final friendRaw = decoded['friendStatusByMxid'];
        final outMap = <String, FriendStatus>{};
        if (friendRaw is Map) {
          friendRaw.forEach((k, v) {
            if (k is String && v is String) {
              outMap[k] = _parseStatus(v);
            }
          });
        }
        final contacts = <Contact>[];
        for (final item in decoded['contacts'] as List) {
          final c = _contactFromMap(item);
          if (c != null) contacts.add(c);
        }
        return GetContactsSuccess(
          contacts: contacts,
          friendStatusByMxid: outMap,
        );
      }
      // 旧版：仅扁平 mxid -> status
      if (decoded is Map) {
        final out = <String, FriendStatus>{};
        decoded.forEach((k, v) {
          if (k is! String || v is! String) return;
          out[k] = _parseStatus(v);
        });
        return GetContactsSuccess(
          contacts: const [],
          friendStatusByMxid: out,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String matrixUserId) async {
    if (matrixUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(matrixUserId));
  }
}
