import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duewise/controllers/activity_controller.dart';
import 'package:duewise/models/academic_activity.dart';
import 'package:duewise/models/discipline.dart';
import 'package:duewise/models/pending_operation.dart';
import 'package:duewise/repositories/activity_cloud_source.dart';
import 'package:duewise/services/firestore_activity_service.dart';
import 'package:duewise/services/local_database.dart';
import 'package:duewise/services/sqlite_activity_repository.dart';
import 'package:duewise/services/synchronized_activity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/sync_fakes.dart';

AcademicActivity activity({
  String id = 'a',
  String uid = 'u1',
  String title = 'Prova',
  String? disciplineId,
}) => AcademicActivity(
  id: id,
  userId: uid,
  title: title,
  disciplineId: disciplineId,
  type: ActivityType.exam,
  dueAt: DateTime(2026, 11, 20, 14),
  createdAt: DateTime(2026, 11, 12),
  updatedAt: DateTime(2026, 11, 12),
);

void main() {
  late Directory directory;
  late LocalDatabase database;
  late SqliteActivityRepository local;
  late TestCloudSource cloud;
  late TestConnectionMonitor network;
  late SynchronizedActivityRepository repository;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('duewise-sync-');
    database = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/duewise.db',
    );
    local = SqliteActivityRepository(database);
    cloud = TestCloudSource();
    network = TestConnectionMonitor(false);
    repository = SynchronizedActivityRepository(
      local: local,
      remote: cloud,
      connection: network,
      retryDelay: const Duration(hours: 1),
      confirmationDelay: const Duration(milliseconds: 40),
    );
  });
  tearDown(() async {
    await repository.stopSession('u1');
    await repository.stopSession('u2');
    await cloud.dispose();
    await network.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });
  Future<void> online() async {
    network.online = true;
    await repository.resume('u1');
    await repository.synchronize('u1');
  }

  Future<void> waitFor(bool Function() predicate) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!predicate()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Condição assíncrona não foi atingida.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  Future<void> reopen() async {
    await repository.stopSession('u1');
    await database.close();
    database = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/duewise.db',
    );
    local = SqliteActivityRepository(database);
    repository = SynchronizedActivityRepository(
      local: local,
      remote: cloud,
      connection: network,
      retryDelay: const Duration(hours: 1),
      confirmationDelay: const Duration(milliseconds: 40),
    );
    await repository.startSession('u1');
  }

  test(
    'offline persiste, envia disciplinas antes, limpa SQLite e mantém dados pela nuvem',
    () async {
      await repository.startSession('u1');
      await repository.insertDiscipline(
        const Discipline(
          id: 'd',
          userId: 'u1',
          name: 'Mobile',
          color: 0xFF245D9F,
        ),
      );
      await repository.insertActivity(activity(disciplineId: 'd'));
      expect(cloud.calls, isEmpty);
      await reopen();
      expect((await repository.listActivities('u1')).single.id, 'a');
      expect(repository.snapshot('u1').state.pendingCount, 2);
      await online();
      expect(cloud.calls.map((op) => op.entity), [
        SyncEntity.discipline,
        SyncEntity.activity,
      ]);
      expect(await local.pending.list('u1'), isEmpty);
      expect(await local.listActivities('u1'), isEmpty);
      expect(await local.listDisciplines('u1'), isEmpty);
      expect((await repository.listActivities('u1')).single.id, 'a');
      network.online = false;
      await reopen();
      expect((await repository.listActivities('u1')).single.id, 'a');
      expect((await repository.listDisciplines('u1')).single.name, 'Mobile');
    },
  );

  test(
    'falha mantém revisão e erro na fila, nova tentativa não duplica documento',
    () async {
      await repository.startSession('u1');
      await repository.insertActivity(activity());
      final revision = (await local.pending.list('u1')).single.revision;
      cloud.failure = const CloudActivityFailure('Sem acesso ao servidor.');
      await online();
      final pending = (await local.pending.list('u1')).single;
      expect(pending.revision, revision);
      expect(pending.attempts, 1);
      expect(pending.lastError, 'Sem acesso ao servidor.');
      cloud.failure = null;
      await repository.synchronize('u1');
      expect(cloud.calls, hasLength(2));
      expect(
        cloud.calls.every((op) => op.id == 'a' && op.revision == revision),
        isTrue,
      );
      expect(cloud.activities['u1'], hasLength(1));
      expect(await local.pending.list('u1'), isEmpty);
    },
  );

  test(
    'resposta perdida após gravação pode ser reenviada com o mesmo ID',
    () async {
      await repository.startSession('u1');
      await repository.insertActivity(activity());
      cloud.failAfterCommitOnce = true;
      await online();
      expect(cloud.activities['u1'], hasLength(1));
      expect(await local.pending.list('u1'), hasLength(1));
      await repository.synchronize('u1');
      expect(cloud.activities['u1'], hasLength(1));
      expect(await local.pending.list('u1'), isEmpty);
    },
  );

  test(
    'confirmação antiga não remove edição nova feita durante o envio',
    () async {
      await repository.startSession('u1');
      await repository.insertActivity(activity());
      cloud.gates.addAll([Completer<void>(), Completer<void>()]);
      network.online = true;
      await repository.resume('u1');
      final flight = repository.synchronize('u1');
      await waitFor(() => cloud.calls.length == 1);
      final oldRevision = cloud.calls.first.revision;
      await repository.updateActivity(activity(title: 'Prova revisada'));
      final newRevision = (await local.pending.list('u1')).single.revision;
      expect(newRevision, isNot(oldRevision));
      cloud.gates[0].complete();
      await waitFor(() => cloud.calls.length == 2);
      expect((await local.pending.list('u1')).single.revision, newRevision);
      expect(
        repository.snapshot('u1').activities.single.title,
        'Prova revisada',
      );
      cloud.gates[1].complete();
      await flight;
      expect(cloud.activities['u1']!['a']!.title, 'Prova revisada');
      expect(await local.pending.list('u1'), isEmpty);
      expect(cloud.maximumConcurrent, 1);
    },
  );

  test(
    'exclusão durante cadastro em envio não reaparece após confirmar o cadastro',
    () async {
      await repository.startSession('u1');
      await repository.insertActivity(activity());
      cloud.gates.addAll([Completer<void>(), Completer<void>()]);
      network.online = true;
      await repository.resume('u1');
      final flight = repository.synchronize('u1');
      await waitFor(() => cloud.calls.length == 1);
      await repository.deleteActivity('u1', 'a');
      expect(repository.snapshot('u1').activities, isEmpty);
      cloud.gates[0].complete();
      await waitFor(() => cloud.calls.length == 2);
      expect(cloud.calls[1].operation, SyncOperation.delete);
      expect(repository.snapshot('u1').activities, isEmpty);
      expect(
        (await local.pending.list('u1')).single.operation,
        SyncOperation.delete,
      );
      cloud.gates[1].complete();
      await flight;
      expect(cloud.activities['u1'], isEmpty);
      expect(await local.pending.list('u1'), isEmpty);
    },
  );

  test(
    'exclusão offline de registro remoto permanece oculta após reabrir',
    () async {
      cloud.activities['u1'] = {'a': activity()};
      await repository.startSession('u1');
      await repository.deleteActivity('u1', 'a');
      await reopen();
      expect(repository.snapshot('u1').activities, isEmpty);
      expect(cloud.activities['u1'], hasLength(1));
      await online();
      expect(cloud.activities['u1'], isEmpty);
      expect(await local.pending.list('u1'), isEmpty);
      cloud.notify('u1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repository.snapshot('u1').activities, isEmpty);
    },
  );

  test(
    'tentativas simultâneas e espera longa usam a mesma escrita em andamento',
    () async {
      await repository.startSession('u1');
      await repository.insertActivity(activity());
      cloud.gates.add(Completer<void>());
      network.online = true;
      await repository.resume('u1');
      final flight = repository.synchronize('u1');
      await waitFor(() => cloud.calls.isNotEmpty);
      final requests = List.generate(10, (_) => repository.synchronize('u1'));
      await waitFor(() => repository.snapshot('u1').state.lastError != null);
      expect(cloud.calls, hasLength(1));
      expect(await local.pending.list('u1'), hasLength(1));
      cloud.gates.single.complete();
      await Future.wait([flight, ...requests]);
      expect(cloud.maximumConcurrent, 1);
      expect(await local.pending.list('u1'), isEmpty);
    },
  );

  test(
    'troca de conta não envia outras pendências nem limpa confirmação da sessão anterior',
    () async {
      await repository.startSession('u1');
      await repository.insertActivity(activity());
      cloud.gates.add(Completer<void>());
      network.online = true;
      await repository.resume('u1');
      final flight = repository.synchronize('u1');
      await waitFor(() => cloud.calls.isNotEmpty);
      network.online = false;
      await repository.startSession('u2');
      await repository.insertActivity(
        activity(id: 'b', uid: 'u2', title: 'Outra conta'),
      );
      cloud.gates.single.complete();
      await flight;
      expect(repository.snapshot('u2').activities.single.id, 'b');
      expect(await local.pending.list('u1'), hasLength(1));
      expect(await local.pending.list('u2'), hasLength(1));
      expect(cloud.calls.every((op) => op.userId == 'u1'), isTrue);
      await repository.stopSession('u1');
      expect(repository.snapshot('u2').activities.single.id, 'b');
    },
  );

  test(
    'controlador acompanha mudanças remotas sem substituir alterações pendentes',
    () async {
      cloud.activities['u1'] = {'a': activity()};
      final controller = ActivityController(
        userId: 'u1',
        repository: repository,
      );
      addTearDown(controller.dispose);
      await controller.load();
      cloud.activities['u1']!['a'] = activity(
        title: 'Editada em outro aparelho',
      );
      cloud.notify('u1');
      await waitFor(
        () => controller.activities.single.title == 'Editada em outro aparelho',
      );
      await controller.save(
        activity(title: 'Minha alteração offline'),
        isNew: false,
      );
      cloud.activities['u1']!['a'] = activity(title: 'Cache antigo');
      cloud.notify('u1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.activities.single.title, 'Minha alteração offline');
      expect(controller.syncState!.pendingCount, 1);
    },
  );

  test('falha de cache após confirmação não apaga a pendência local', () async {
    await repository.startSession('u1');
    await repository.insertActivity(activity());
    cloud.failCache = true;
    await online();
    expect(await local.pending.list('u1'), hasLength(1));
    expect(repository.snapshot('u1').activities.single.id, 'a');
    cloud.failCache = false;
    await repository.synchronize('u1');
    expect(await local.pending.list('u1'), isEmpty);
  });

  test(
    'migração v1 preserva IDs e dados de todas as contas em pendências v2',
    () async {
      final original = activity(disciplineId: 'd');
      final legacy = await databaseFactoryFfi.openDatabase(
        '${directory.path}/duewise.db',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE disciplines (id TEXT, user_id TEXT, name TEXT, color INTEGER)',
            );
            await db.execute(
              '''CREATE TABLE activities (
          id TEXT, user_id TEXT, title TEXT, discipline_id TEXT, type TEXT, description TEXT,
          due_at INTEGER, priority TEXT, completed INTEGER, location TEXT,
          latitude REAL, longitude REAL, created_at INTEGER, updated_at INTEGER)''',
            );
          },
        ),
      );
      await legacy.insert(
        'disciplines',
        const Discipline(
          id: 'd',
          userId: 'u1',
          name: 'Mobile',
          color: 1,
        ).toMap(),
      );
      await legacy.insert('activities', original.toMap()..remove('address'));
      await legacy.insert(
        'activities',
        activity(id: 'other', uid: 'u2').toMap()..remove('address'),
      );
      await legacy.close();
      await repository.startSession('u1');
      expect(
        (await repository.listActivities('u1')).single.toMap(),
        original.toMap(),
      );
      expect((await local.pending.list('u1')).length, 2);
      expect((await local.pending.list('u2')).single.id, 'other');
      expect(await (await database.database).getVersion(), 2);
      final legacyTables = await (await database.database).rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('activities', 'disciplines')",
      );
      expect(legacyTables, isEmpty);
      await online();
      expect(await local.pending.list('u1'), isEmpty);
      expect((await local.pending.list('u2')).single.id, 'other');
      expect(cloud.calls.every((op) => op.userId == 'u1'), isTrue);
    },
  );

  test('retorno da rede dispara envio automaticamente', () async {
    await repository.startSession('u1');
    await repository.insertActivity(activity());
    network.change(true);
    await waitFor(
      () =>
          repository.snapshot('u1').state.pendingCount == 0 &&
          cloud.calls.length == 1,
    );
    network.change(false);
    await waitFor(() => !repository.snapshot('u1').state.hasConnection);
    await repository.insertActivity(activity(id: 'b'));
    expect(cloud.calls, hasLength(1));
    network.change(true);
    await waitFor(
      () =>
          repository.snapshot('u1').state.pendingCount == 0 &&
          cloud.calls.length == 2,
    );
  });

  test(
    'serialização Firestore preserva IDs, tipos, horários e proprietário',
    () {
      final model = activity();
      final operation = PendingOperation(
        userId: 'u1',
        entity: SyncEntity.activity,
        id: 'a',
        operation: SyncOperation.upsert,
        payload: model.toMap(),
        revision: 'r1',
        createdAt: 1,
      );
      final encoded = FirestoreActivityService.encode(operation);
      expect(encoded['dueAt'], isA<Timestamp>());
      expect(encoded['completed'], isFalse);
      expect(encoded['mutationId'], 'r1');
      expect(
        FirestoreActivityService.decodeActivity('u1', 'a', encoded).toMap(),
        model.toMap(),
      );
      expect(
        () => FirestoreActivityService.decodeActivity('u2', 'a', encoded),
        throwsA(isA<CloudActivityFailure>()),
      );
    },
  );
}
