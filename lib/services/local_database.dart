import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class LocalDatabase {
  LocalDatabase({this._factory, String? databasePath}) : _path = databasePath;
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
          version: 2,
          onCreate: (db, version) => _createQueue(db),
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await _createQueue(db);
              // onUpgrade executa em transação: qualquer falha preserva o banco v1.
              for (final table in ['disciplines', 'activities']) {
                final entity = table == 'disciplines'
                    ? 'discipline'
                    : 'activity';
                for (final row in await db.query(table)) {
                  await db.insert('pending_operations', {
                    'user_id': row['user_id'],
                    'entity': entity,
                    'record_id': row['id'],
                    'operation': 'upsert',
                    'payload': jsonEncode(row),
                    'revision': const Uuid().v4(),
                    'created_at':
                        row['created_at'] ??
                        DateTime.now().millisecondsSinceEpoch,
                    'attempts': 0,
                  });
                }
              }
              await db.execute('DROP TABLE activities');
              await db.execute('DROP TABLE disciplines');
            }
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> _createQueue(Database db) async {
    await db.execute('''CREATE TABLE pending_operations (
      user_id TEXT NOT NULL, entity TEXT NOT NULL CHECK(entity IN ('activity', 'discipline')),
      record_id TEXT NOT NULL, operation TEXT NOT NULL CHECK(operation IN ('upsert', 'delete')),
      payload TEXT NOT NULL, revision TEXT NOT NULL, created_at INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT,
      PRIMARY KEY (user_id, entity, record_id)
    )''');
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening == null) return;
    final db = await opening;
    await db.close();
    _opening = null;
  }
}
