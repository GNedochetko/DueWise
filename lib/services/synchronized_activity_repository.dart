import 'dart:async';
import '../models/academic_activity.dart';
import '../models/activity_sync_state.dart';
import '../models/discipline.dart';
import '../models/pending_operation.dart';
import '../repositories/activity_cloud_source.dart';
import '../repositories/activity_repository.dart';
import '../repositories/synchronizing_activity_repository.dart';
import 'sqlite_activity_repository.dart';

class SynchronizedActivityRepository
    implements SynchronizingActivityRepository {
  SynchronizedActivityRepository({
    required this.local,
    required this.remote,
    required this.connection,
    this.retryDelay = const Duration(seconds: 10),
    this.confirmationDelay = const Duration(seconds: 20),
  });
  final SqliteActivityRepository local;
  final ActivityCloudSource remote;
  final ConnectionMonitor connection;
  final Duration retryDelay;
  final Duration confirmationDelay;
  final _updates =
      StreamController<({String uid, ActivitySyncUpdate update})>.broadcast();
  _Session? _session;

  bool _current(_Session session) =>
      identical(_session, session) && session.active;
  @override
  Stream<ActivitySyncUpdate> watchSession(String userId) => _updates.stream
      .where((event) => event.uid == userId)
      .map((event) => event.update);
  @override
  ActivitySyncUpdate snapshot(String userId) {
    final session = _session;
    if (session == null || session.uid != userId) {
      return const ActivitySyncUpdate(
        activities: [],
        disciplines: [],
        state: ActivitySyncState(),
      );
    }
    return ActivitySyncUpdate(
      activities: List.unmodifiable(session.activities),
      disciplines: List.unmodifiable(session.disciplines),
      state: ActivitySyncState(
        pendingCount: session.pendingCount,
        synchronizing: session.synchronizing,
        hasConnection: session.online,
        lastError: session.error,
      ),
    );
  }

  void _publish(_Session session) {
    if (_current(session)) {
      _updates.add((uid: session.uid, update: snapshot(session.uid)));
    }
  }

  @override
  Future<void> startSession(String userId) {
    final existing = _session;
    if (existing != null && existing.uid == userId && existing.active) {
      return existing.ready;
    }
    if (existing != null) unawaited(stopSession(existing.uid));
    final session = _Session(userId);
    _session = session;
    session.ready = _initialize(session);
    return session.ready;
  }

  Future<void> _initialize(_Session session) async {
    try {
      await _refresh(session);
      if (!_current(session)) return;
      _watchRemote(session);
      session.network = connection.changes.listen((online) {
        if (!_current(session)) return;
        session.online = online;
        _publish(session);
        if (online) unawaited(synchronize(session.uid));
      }, onError: (Object _) {});
      try {
        session.online = await connection.check().timeout(
          const Duration(seconds: 3),
        );
      } catch (_) {
        session.online = true;
      }
      _publish(session);
      if (_current(session)) unawaited(synchronize(session.uid));
    } catch (_) {
      if (_current(session)) unawaited(stopSession(session.uid));
      rethrow;
    }
  }

  void _watchRemote(_Session session) {
    session.watchFailed = false;
    session.cloud = remote
        .watch(session.uid)
        .listen(
          (_) {
            if (!_current(session)) return;
            unawaited(
              _refresh(session).catchError((Object error) {
                if (_current(session)) {
                  session.error = _message(error);
                  _publish(session);
                }
              }),
            );
          },
          onError: (Object error) {
            if (!_current(session)) return;
            session.watchFailed = true;
            session.error = _message(error);
            _publish(session);
            _scheduleRetry(session);
          },
        );
  }

  @override
  Future<void> stopSession(String userId) async {
    final session = _session;
    if (session == null || session.uid != userId) return;
    _session = null;
    session.active = false;
    session.retry?.cancel();
    session.waiting?.cancel();
    await session.cloud?.cancel();
    await session.network?.cancel();
    // Escritas já entregues ao SDK não são reenviadas em paralelo nem apagadas da fila.
  }

  @override
  Future<void> resume(String userId) async {
    await startSession(userId);
    final session = _requireSession(userId);
    try {
      session.online = await connection.check().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      /* A resposta do servidor continua sendo a confirmação real. */
    }
    await _refresh(session);
    unawaited(synchronize(userId));
  }

  _Session _requireSession(String uid) {
    final session = _session;
    if (session == null || session.uid != uid || !session.active) {
      throw const ActivityFailure(
        'Entre novamente para acessar suas atividades.',
      );
    }
    return session;
  }

  Future<void> _ensure(String uid) => startSession(uid);

  /// Serializa leituras do cache e da fila para não publicar resultados antigos
  /// depois de uma gravação mais recente.
  Future<void> _refresh(_Session session, {bool requireCache = false}) {
    final work = session.refreshTail.then((_) async {
      if (!_current(session)) return;
      try {
        session.remoteRecords = await remote.readCache(session.uid);
      } catch (error) {
        if (requireCache) rethrow;
        session.error = _message(error);
      }
      final pending = await local.pending.list(session.uid);
      if (!_current(session)) return;
      final activities = {
        for (final item in session.remoteRecords.activities) item.id: item,
      };
      final disciplines = {
        for (final item in session.remoteRecords.disciplines) item.id: item,
      };
      for (final op in pending) {
        if (op.entity == SyncEntity.activity) {
          if (op.operation == SyncOperation.delete) {
            activities.remove(op.id);
          } else {
            activities[op.id] = AcademicActivity.fromMap(op.payload);
          }
        } else {
          if (op.operation == SyncOperation.delete) {
            disciplines.remove(op.id);
          } else {
            disciplines[op.id] = Discipline.fromMap(op.payload);
          }
        }
      }
      session.activities = activities.values.toList()
        ..sort((a, b) {
          final due = a.dueAt.compareTo(b.dueAt);
          return due != 0 ? due : a.id.compareTo(b.id);
        });
      session.disciplines = disciplines.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      session.pendingCount = pending.length;
      if (session.error == null) {
        for (final op in pending) {
          if (op.lastError != null) {
            session.error = op.lastError;
            break;
          }
        }
      }
      _publish(session);
    });
    session.refreshTail = work.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return work;
  }

  @override
  Future<void> synchronize(String userId) {
    final session = _session;
    if (session == null || session.uid != userId || !session.active) {
      return Future.value();
    }
    session.syncRequested = true;
    if (session.flight != null) return session.flight!;
    session.retry?.cancel();
    session.flight = Future<void>.microtask(() => _drain(session)).whenComplete(
      () {
        session.flight = null;
        if (_current(session) && session.syncRequested && session.online) {
          unawaited(synchronize(session.uid));
        }
      },
    );
    return session.flight!;
  }

  Future<void> _drain(_Session session) async {
    if (!_current(session) || !session.online) {
      _publish(session);
      return;
    }
    if (session.watchFailed) {
      await session.cloud?.cancel();
      if (!_current(session)) return;
      _watchRemote(session);
    }
    session.synchronizing = true;
    session.error = null;
    _publish(session);
    try {
      while (_current(session) && session.online) {
        session.syncRequested = false;
        final pending = await local.pending.list(session.uid);
        if (pending.isEmpty) {
          await _refresh(session);
          break;
        }
        for (final op in pending) {
          if (!_current(session) || !session.online) return;
          final latest = await local.pending.find(op.userId, op.entity, op.id);
          if (latest?.revision != op.revision) continue;
          session.waiting?.cancel();
          session.waiting = Timer(confirmationDelay, () {
            if (_current(session)) {
              session.error =
                  'Aguardando confirmação do envio. Suas alterações continuam salvas neste aparelho.';
              _publish(session);
            }
          });
          try {
            // Não aplicar timeout que abandone esta Future: o SDK pode ainda
            // estar com a escrita em voo. Reenvios aguardam a mesma execução.
            await remote.apply(op);
            session.waiting?.cancel();
            if (!_current(session)) return;
            await _refresh(session, requireCache: true);
            if (!_current(session)) return;
            await local.pending.acknowledge(op);
            session.error = null;
            session.failures = 0;
            await _refresh(session);
          } catch (error) {
            session.waiting?.cancel();
            if (!_current(session)) return;
            final message = _message(error);
            await local.pending.recordFailure(op, message);
            session.error = message;
            await _refresh(session);
            _scheduleRetry(session);
            return;
          }
        }
      }
    } catch (error) {
      if (_current(session)) {
        session.error = _message(error);
        _scheduleRetry(session);
      }
    } finally {
      session.waiting?.cancel();
      session.synchronizing = false;
      _publish(session);
    }
  }

  void _scheduleRetry(_Session session) {
    if (!_current(session)) return;
    session.retry?.cancel();
    session.syncRequested = false;
    final multiplier = 1 << session.failures.clamp(0, 3);
    session.failures++;
    session.retry = Timer(retryDelay * multiplier, () {
      if (_current(session)) unawaited(synchronize(session.uid));
    });
  }

  String _message(Object error) => switch (error) {
    CloudActivityFailure() => error.message,
    ActivityFailure() => error.message,
    _ =>
      'Não foi possível sincronizar agora. Suas alterações foram preservadas.',
  };

  Future<void> _changed(_Session session) async {
    await _refresh(session);
    if (_current(session)) unawaited(synchronize(session.uid));
  }

  @override
  Future<List<AcademicActivity>> listActivities(String userId) async {
    await _ensure(userId);
    return List.of(_requireSession(userId).activities);
  }

  @override
  Future<List<Discipline>> listDisciplines(String userId) async {
    await _ensure(userId);
    return List.of(_requireSession(userId).disciplines);
  }

  @override
  Future<AcademicActivity?> findActivity(String userId, String id) async {
    for (final activity in await listActivities(userId)) {
      if (activity.id == id) return activity;
    }
    return null;
  }

  Future<void> _validateDiscipline(
    AcademicActivity activity, {
    AcademicActivity? previous,
  }) async {
    if (activity.disciplineId != null &&
        activity.disciplineId != previous?.disciplineId &&
        !(await listDisciplines(
          activity.userId,
        )).any((d) => d.id == activity.disciplineId)) {
      throw const ActivityFailure('Selecione uma disciplina desta conta.');
    }
  }

  @override
  Future<void> insertActivity(AcademicActivity activity) async {
    await _ensure(activity.userId);
    final session = _requireSession(activity.userId);
    if (await findActivity(activity.userId, activity.id) != null) {
      throw const ActivityFailure('Esta atividade já existe.');
    }
    await _validateDiscipline(activity);
    await local.enqueueActivity(activity);
    await _changed(session);
  }

  @override
  Future<void> updateActivity(AcademicActivity activity) async {
    final previous = await findActivity(activity.userId, activity.id);
    if (previous == null) {
      throw const ActivityFailure('Esta atividade não está mais disponível.');
    }
    final session = _requireSession(activity.userId);
    await _validateDiscipline(activity, previous: previous);
    await local.enqueueActivity(
      AcademicActivity.fromMap({
        ...activity.toMap(),
        'created_at': previous.createdAt.millisecondsSinceEpoch,
      }),
    );
    await _changed(session);
  }

  @override
  Future<void> setCompleted(
    String userId,
    String id,
    bool completed,
    DateTime updatedAt,
  ) async {
    final previous = await findActivity(userId, id);
    if (previous == null) {
      throw const ActivityFailure('Esta atividade não está mais disponível.');
    }
    await local.enqueueActivity(previous.withCompletion(completed, updatedAt));
    await _changed(_requireSession(userId));
  }

  @override
  Future<void> deleteActivity(String userId, String id) async {
    if (await findActivity(userId, id) == null) {
      throw const ActivityFailure('Esta atividade não está mais disponível.');
    }
    await local.enqueueDeletion(userId, id);
    await _changed(_requireSession(userId));
  }

  @override
  Future<void> insertDiscipline(Discipline discipline) async {
    final current = await listDisciplines(discipline.userId);
    if (current.any(
      (d) => d.name.toLowerCase() == discipline.name.toLowerCase(),
    )) {
      throw const ActivityFailure('Já existe uma disciplina com esse nome.');
    }
    await local.insertDiscipline(discipline);
    await _changed(_requireSession(discipline.userId));
  }
}

class _Session {
  _Session(this.uid);
  final String uid;
  bool active = true;
  bool online = true;
  bool synchronizing = false;
  bool watchFailed = false;
  bool syncRequested = false;
  int pendingCount = 0;
  int failures = 0;
  String? error;
  late Future<void> ready;
  Future<void>? flight;
  Future<void> refreshTail = Future.value();
  CloudActivityRecords remoteRecords = const CloudActivityRecords();
  List<AcademicActivity> activities = [];
  List<Discipline> disciplines = [];
  StreamSubscription<void>? cloud;
  StreamSubscription<bool>? network;
  Timer? retry;
  Timer? waiting;
}
