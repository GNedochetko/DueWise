import '../models/academic_activity.dart';
import '../models/discipline.dart';
import '../models/pending_operation.dart';
import '../repositories/activity_repository.dart';
import 'local_database.dart';
import 'pending_operations_store.dart';

/// Visão local das alterações ainda não confirmadas pelo servidor.
class SqliteActivityRepository implements ActivityRepository {
  SqliteActivityRepository(LocalDatabase database)
    : pending = PendingOperationsStore(database);
  final PendingOperationsStore pending;
  @override
  Future<List<AcademicActivity>> listActivities(String userId) async {
    final items = (await pending.list(userId))
        .where(
          (op) =>
              op.entity == SyncEntity.activity &&
              op.operation == SyncOperation.upsert,
        )
        .map((op) => AcademicActivity.fromMap(op.payload))
        .toList();
    items.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return items;
  }

  @override
  Future<AcademicActivity?> findActivity(String userId, String id) async {
    final op = await pending.find(userId, SyncEntity.activity, id);
    return op == null || op.operation == SyncOperation.delete
        ? null
        : AcademicActivity.fromMap(op.payload);
  }

  Future<void> _validateDiscipline(AcademicActivity activity) async {
    if (activity.disciplineId != null &&
        !(await listDisciplines(
          activity.userId,
        )).any((d) => d.id == activity.disciplineId)) {
      throw const ActivityFailure('Selecione uma disciplina desta conta.');
    }
  }

  @override
  Future<void> insertActivity(AcademicActivity activity) async {
    if (await findActivity(activity.userId, activity.id) != null) {
      throw const ActivityFailure('Esta atividade já existe.');
    }
    await _validateDiscipline(activity);
    await enqueueActivity(activity);
  }

  Future<void> enqueueActivity(AcademicActivity activity) async {
    if (activity.title.trim().isEmpty) {
      throw const ActivityFailure('Informe o título da atividade.');
    }
    await pending.put(
      userId: activity.userId,
      entity: SyncEntity.activity,
      id: activity.id,
      operation: SyncOperation.upsert,
      payload: activity.toMap(),
    );
  }

  @override
  Future<void> updateActivity(AcademicActivity activity) async {
    final existing = await findActivity(activity.userId, activity.id);
    if (existing == null) {
      throw const ActivityFailure('Esta atividade não está mais disponível.');
    }
    await _validateDiscipline(activity);
    await enqueueActivity(
      AcademicActivity.fromMap({
        ...activity.toMap(),
        'created_at': existing.createdAt.millisecondsSinceEpoch,
      }),
    );
  }

  @override
  Future<void> setCompleted(
    String userId,
    String id,
    bool completed,
    DateTime updatedAt,
  ) async {
    final activity = await findActivity(userId, id);
    if (activity == null) {
      throw const ActivityFailure('Esta atividade não está mais disponível.');
    }
    await enqueueActivity(activity.withCompletion(completed, updatedAt));
  }

  @override
  Future<void> deleteActivity(String userId, String id) async {
    final activity = await findActivity(userId, id);
    if (activity == null) {
      throw const ActivityFailure('Esta atividade não está mais disponível.');
    }
    await enqueueDeletion(userId, id);
  }

  Future<void> enqueueDeletion(String userId, String id) async {
    // Mesmo um cadastro em envio pode chegar ao servidor; registrar a exclusão é seguro.
    await pending.put(
      userId: userId,
      entity: SyncEntity.activity,
      id: id,
      operation: SyncOperation.delete,
      payload: {'id': id, 'user_id': userId},
    );
  }

  @override
  Future<List<Discipline>> listDisciplines(String userId) async =>
      (await pending.list(userId))
          .where(
            (op) =>
                op.entity == SyncEntity.discipline &&
                op.operation == SyncOperation.upsert,
          )
          .map((op) => Discipline.fromMap(op.payload))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  @override
  Future<void> insertDiscipline(Discipline discipline) async {
    if ((await listDisciplines(
      discipline.userId,
    )).any((d) => d.name.toLowerCase() == discipline.name.toLowerCase())) {
      throw const ActivityFailure('Já existe uma disciplina com esse nome.');
    }
    await pending.put(
      userId: discipline.userId,
      entity: SyncEntity.discipline,
      id: discipline.id,
      operation: SyncOperation.upsert,
      payload: discipline.toMap(),
    );
  }
}
