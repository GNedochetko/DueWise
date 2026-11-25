import 'package:duewise/models/activity_address.dart';
import 'dart:io';
import 'package:duewise/controllers/activity_controller.dart';
import 'package:duewise/models/academic_activity.dart';
import 'package:duewise/models/discipline.dart';
import 'package:duewise/repositories/activity_repository.dart';
import 'package:duewise/services/local_database.dart';
import 'package:duewise/services/sqlite_activity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

AcademicActivity makeActivity({
  String id = 'a1',
  String owner = 'u1',
  String? disciplineId,
  String title = "Prova d'Álgebra",
  bool completed = false,
}) => AcademicActivity(
  id: id,
  userId: owner,
  title: title,
  disciplineId: disciplineId,
  type: ActivityType.exam,
  dueAt: DateTime(2026, 11, 20, 14, 30),
  createdAt: DateTime(2026, 11, 12, 9),
  updatedAt: DateTime(2026, 11, 12, 9),
  description: 'Capítulos 1 e 2',
  priority: ActivityPriority.high,
  location: 'Sala 12',
  address: const ActivityAddress(
    cep: '01001000',
    street: 'Praça da Sé',
    city: 'São Paulo',
    state: 'SP',
    number: '10',
  ),
  latitude: -25.38,
  longitude: -51.46,
  completed: completed,
);

void main() {
  late Directory directory;
  late LocalDatabase database;
  late SqliteActivityRepository repository;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('duewise-sqlite-');
    database = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/activities.db',
    );
    repository = SqliteActivityRepository(database);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<void> reopen() async {
    await database.close();
    database = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/activities.db',
    );
    repository = SqliteActivityRepository(database);
  }

  test(
    'CRUD completo persiste dados e conclusão após fechar e reabrir o arquivo',
    () async {
      await repository.insertDiscipline(
        const Discipline(
          id: 'd1',
          userId: 'u1',
          name: 'Matemática',
          color: 0xFF245D9F,
        ),
      );
      final activity = makeActivity(disciplineId: 'd1');
      await repository.insertActivity(activity);
      await reopen();
      final restored = (await repository.listActivities('u1')).single;
      expect(restored.toMap(), activity.toMap());
      expect(
        (await repository.listDisciplines('u1')).single.name,
        'Matemática',
      );
      final edited = AcademicActivity.fromMap({
        ...restored.toMap(),
        'title': 'Prova revisada',
        'description': 'Levar calculadora',
        'updated_at': DateTime(2026, 11, 13).millisecondsSinceEpoch,
        'created_at': DateTime(2099).millisecondsSinceEpoch,
      });
      await repository.updateActivity(edited);
      await repository.setCompleted(
        'u1',
        activity.id,
        true,
        DateTime(2026, 11, 14),
      );
      await reopen();
      final updated = (await repository.findActivity('u1', activity.id))!;
      expect(updated.title, 'Prova revisada');
      expect(updated.description, 'Levar calculadora');
      expect(updated.createdAt, activity.createdAt);
      expect(updated.updatedAt, DateTime(2026, 11, 14));
      expect(updated.completed, isTrue);
      expect(updated.address?.number, '10');
      await repository.setCompleted(
        'u1',
        activity.id,
        false,
        DateTime(2026, 11, 15),
      );
      expect(
        (await repository.findActivity('u1', activity.id))!.completed,
        isFalse,
      );
      await repository.deleteActivity('u1', activity.id);
      await reopen();
      expect(await repository.listActivities('u1'), isEmpty);
      expect(await repository.findActivity('u1', activity.id), isNull);
    },
  );

  test(
    'consulta, edição, conclusão e exclusão são restritas ao proprietário',
    () async {
      final activity = makeActivity();
      await repository.insertActivity(activity);
      await repository.insertActivity(
        makeActivity(id: 'a2', owner: 'u2', title: 'Privada de u2'),
      );
      expect((await repository.listActivities('u1')).map((a) => a.id), ['a1']);
      expect((await repository.listActivities('u2')).map((a) => a.id), ['a2']);
      expect(await repository.findActivity('u2', 'a1'), isNull);
      final foreign = AcademicActivity.fromMap({
        ...activity.toMap(),
        'user_id': 'u2',
        'title': 'Inválida',
      });
      await expectLater(
        repository.updateActivity(foreign),
        throwsA(isA<ActivityFailure>()),
      );
      await expectLater(
        repository.setCompleted('u2', 'a1', true, DateTime.now()),
        throwsA(isA<ActivityFailure>()),
      );
      await expectLater(
        repository.deleteActivity('u2', 'a1'),
        throwsA(isA<ActivityFailure>()),
      );
      expect(
        (await repository.findActivity('u1', 'a1'))!.toMap(),
        activity.toMap(),
      );
    },
  );

  test(
    'repositório impede associar disciplina pertencente a outra conta',
    () async {
      await repository.insertDiscipline(
        const Discipline(id: 'd1', userId: 'u1', name: 'Cálculo', color: 1),
      );
      await expectLater(
        repository.insertActivity(
          makeActivity(owner: 'u2', disciplineId: 'd1'),
        ),
        throwsA(isA<ActivityFailure>()),
      );
      expect(await repository.listActivities('u2'), isEmpty);
    },
  );

  test(
    'disciplinas repetidas são recusadas apenas dentro da mesma conta',
    () async {
      await repository.insertDiscipline(
        const Discipline(id: 'd1', userId: 'u1', name: 'Cálculo', color: 1),
      );
      await expectLater(
        repository.insertDiscipline(
          const Discipline(id: 'd2', userId: 'u1', name: 'cálculo', color: 2),
        ),
        throwsA(isA<ActivityFailure>()),
      );
      await repository.insertDiscipline(
        const Discipline(id: 'd3', userId: 'u2', name: 'Cálculo', color: 3),
      );
      expect((await repository.listDisciplines('u2')).single.id, 'd3');
    },
  );

  test(
    'controlador recarrega atividades reais e rejeita salvar em nome de outra conta',
    () async {
      final controller = ActivityController(
        userId: 'u1',
        repository: repository,
      );
      addTearDown(controller.dispose);
      await controller.load();
      await controller.save(makeActivity(), isNew: true);
      await controller.load();
      expect(controller.activities.single.id, 'a1');
      await expectLater(
        controller.save(makeActivity(id: 'foreign', owner: 'u2'), isNew: true),
        throwsA(isA<ActivityFailure>()),
      );
      await controller.setCompleted('a1', true);
      expect(controller.activities.single.completed, isTrue);
      await controller.delete('a1');
      expect(controller.activities, isEmpty);
    },
  );
}
