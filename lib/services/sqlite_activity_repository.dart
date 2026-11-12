import 'package:sqflite/sqflite.dart';
import '../models/academic_activity.dart';
import '../models/discipline.dart';
import '../repositories/activity_repository.dart';
import 'local_database.dart';

class SqliteActivityRepository implements ActivityRepository {
  SqliteActivityRepository(this._local);
  final LocalDatabase _local;
  Future<T> _run<T>(Future<T> Function(Database db) action) async {
    try {
      return await action(await _local.database);
    } on DatabaseException catch (_) {
      throw const ActivityFailure(
        'Não foi possível acessar as atividades salvas. Tente novamente.',
      );
    }
  }

  @override
  Future<List<AcademicActivity>> listActivities(String userId) =>
      _run((db) async {
        final rows = await db.query(
          'activities',
          where: 'user_id = ?',
          whereArgs: [userId],
          orderBy: 'due_at ASC, created_at ASC, id ASC',
        );
        return rows.map(AcademicActivity.fromMap).toList();
      });
  @override
  Future<AcademicActivity?> findActivity(String userId, String id) =>
      _run((db) async {
        final rows = await db.query(
          'activities',
          where: 'user_id = ? AND id = ?',
          whereArgs: [userId, id],
          limit: 1,
        );
        return rows.isEmpty ? null : AcademicActivity.fromMap(rows.first);
      });
  @override
  Future<void> insertActivity(AcademicActivity activity) => _run((db) async {
    await db.insert('activities', activity.toMap());
  });
  @override
  Future<void> updateActivity(AcademicActivity activity) => _run((db) async {
    final values = activity.toMap()
      ..remove('id')
      ..remove('user_id')
      ..remove('created_at');
    final count = await db.update(
      'activities',
      values,
      where: 'user_id = ? AND id = ?',
      whereArgs: [activity.userId, activity.id],
    );
    _requireFound(count);
  });
  @override
  Future<void> setCompleted(
    String userId,
    String id,
    bool completed,
    DateTime updatedAt,
  ) => _run((db) async {
    final count = await db.update(
      'activities',
      {
        'completed': completed ? 1 : 0,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      },
      where: 'user_id = ? AND id = ?',
      whereArgs: [userId, id],
    );
    _requireFound(count);
  });
  @override
  Future<void> deleteActivity(String userId, String id) => _run((db) async {
    final count = await db.delete(
      'activities',
      where: 'user_id = ? AND id = ?',
      whereArgs: [userId, id],
    );
    _requireFound(count);
  });
  @override
  Future<List<Discipline>> listDisciplines(String userId) => _run((db) async {
    final rows = await db.query(
      'disciplines',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Discipline.fromMap).toList();
  });
  @override
  Future<void> insertDiscipline(Discipline discipline) async {
    try {
      final db = await _local.database;
      await db.insert('disciplines', discipline.toMap());
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError())
        throw const ActivityFailure('Já existe uma disciplina com esse nome.');
      throw const ActivityFailure(
        'Não foi possível salvar a disciplina. Tente novamente.',
      );
    }
  }

  void _requireFound(int count) {
    if (count == 0)
      throw const ActivityFailure('Esta atividade não está mais disponível.');
  }
}
