import 'package:fluffychat/utils/open_sqflite_db.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:matrix/matrix.dart';

/// Ensures the global [Client] has a usable Matrix SDK database before
/// [Client.init] (e.g. Zeon recover / mining login).
///
/// After a failed [Client.init], the SDK may call [Client.clear] → [dispose],
/// which closes SQLite; the same [Client] instance is then unusable until the
/// underlying [MatrixSdkDatabase] is replaced ([Client.database] setter).
class ZeonMatrixClientDatabase {
  ZeonMatrixClientDatabase._();

  static bool _isClosedStoreError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('database_closed') ||
        s.contains('this database has already been closed');
  }

  /// No-op when not on mobile (no sqflite path) or when already logged in.
  static Future<void> ensureOpenBeforeInit(Client client) async {
    if (!PlatformInfos.isMobile) return;
    if (client.isLogged()) return;

    try {
      await client.database.getClient(client.clientName);
      return;
    } catch (e) {
      if (!_isClosedStoreError(e)) rethrow;
    }

    Logs().w(
      'ZeonMatrixClientDatabase: local store was closed; rebuilding for '
      '${client.clientName}',
    );

    final oldApi = client.database;
    String? dbPath;
    if (oldApi is MatrixSdkDatabase) {
      dbPath = oldApi.database?.path;
    }

    try {
      await oldApi.close();
    } catch (_) {}

    if (dbPath != null) {
      try {
        await deleteSqfliteDb(dbPath);
      } catch (_) {}
    }

    final db = await openSqfliteDb(name: client.clientName);
    if (db == null) return;

    client.database = await MatrixSdkDatabase.init(
      client.clientName,
      database: db,
    );
  }
}
