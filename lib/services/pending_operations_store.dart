import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/pending_operation.dart';
import '../repositories/activity_repository.dart';
import 'local_database.dart';

class PendingOperationsStore {
  PendingOperationsStore(this.database);
  final LocalDatabase database;
  Future<T> _run<T>(Future<T> Function(Database db) action) async {
    try {
      return await action(await database.database);
    } on DatabaseException {
      throw const ActivityFailure(
        'Não foi possível acessar as alterações salvas neste aparelho.',
      );
    }
  }

  Future<List<PendingOperation>> list(String userId) => _run((db) async {
    final rows = await db.query(
      'pending_operations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy:
          "CASE entity WHEN 'discipline' THEN 0 ELSE 1 END, created_at, record_id",
    );
    return rows.map(PendingOperation.fromMap).toList();
  });
  Future<PendingOperation?> find(String userId, SyncEntity entity, String id) =>
      _run((db) async {
        final rows = await db.query(
          'pending_operations',
          where: 'user_id = ? AND entity = ? AND record_id = ?',
          whereArgs: [userId, entity.name, id],
          limit: 1,
        );
        return rows.isEmpty ? null : PendingOperation.fromMap(rows.single);
      });
  Future<PendingOperation> put({
    required String userId,
    required SyncEntity entity,
    required String id,
    required SyncOperation operation,
    required Map<String, Object?> payload,
  }) => _run((db) async {
    final pending = PendingOperation(
      userId: userId,
      entity: entity,
      id: id,
      operation: operation,
      payload: Map.unmodifiable(payload),
      revision: const Uuid().v4(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await db.insert(
      'pending_operations',
      pending.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return pending;
  });
  Future<bool> acknowledge(PendingOperation operation) => _run(
    (db) async =>
        await db.delete(
          'pending_operations',
          where:
              'user_id = ? AND entity = ? AND record_id = ? AND revision = ?',
          whereArgs: [
            operation.userId,
            operation.entity.name,
            operation.id,
            operation.revision,
          ],
        ) ==
        1,
  );
  Future<void> recordFailure(
    PendingOperation operation,
    String message,
  ) => _run((db) async {
    await db.rawUpdate(
      '''UPDATE pending_operations SET attempts = attempts + 1, last_error = ?
      WHERE user_id = ? AND entity = ? AND record_id = ? AND revision = ?''',
      [
        message,
        operation.userId,
        operation.entity.name,
        operation.id,
        operation.revision,
      ],
    );
  });
}
