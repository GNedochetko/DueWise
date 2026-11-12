import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Uma conexão compartilhada; a conta é isolada pelas chaves e consultas.
class LocalDatabase {
  LocalDatabase({DatabaseFactory? factory, String? databasePath})
    : _factory = factory,
      _path = databasePath;
  final DatabaseFactory? _factory;
  final String? _path;
  Future<Database>? _opening;
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    try {
      final factory = _factory ?? databaseFactory;
      final databasePath =
          _path ?? path.join(await factory.getDatabasesPath(), 'duewise.db');
      return await factory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) async {
            await db.execute('''CREATE TABLE disciplines (
            id TEXT NOT NULL, user_id TEXT NOT NULL,
            name TEXT NOT NULL COLLATE NOCASE, color INTEGER NOT NULL,
            PRIMARY KEY (user_id, id), UNIQUE (user_id, name)
          )''');
            await db.execute('''CREATE TABLE activities (
            id TEXT NOT NULL, user_id TEXT NOT NULL,
            title TEXT NOT NULL CHECK(length(trim(title)) > 0),
            discipline_id TEXT, type TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '', due_at INTEGER NOT NULL,
            priority TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0, 1)),
            location TEXT NOT NULL DEFAULT '', latitude REAL, longitude REAL,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
            PRIMARY KEY (user_id, id),
            FOREIGN KEY (user_id, discipline_id) REFERENCES disciplines(user_id, id)
          )''');
            await db.execute(
              'CREATE INDEX activities_user_due ON activities(user_id, due_at)',
            );
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening == null) return;
    final db = await opening;
    await db.close();
    _opening = null;
  }
}
