import 'package:duewise/app.dart';
import 'package:duewise/models/academic_activity.dart';
import 'package:duewise/models/app_user.dart';
import 'package:flutter/material.dart';
import 'support/app_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'support/fakes.dart';

AcademicActivity sample({
  required String id,
  required String title,
  ActivityType type = ActivityType.exam,
  bool completed = false,
  DateTime? dueAt,
  String userId = 'student-1',
}) => AcademicActivity(
  id: id,
  userId: userId,
  title: title,
  type: type,
  dueAt: dueAt ?? DateTime.now().add(const Duration(days: 1)),
  completed: completed,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;
  late MemoryActivityRepository activities;
  setUpAll(loadAppFonts);
  setUp(() {
    auth = FakeAuthRepository(initialUser: student);
    profiles = FakeProfileRepository();
    activities = MemoryActivityRepository();
  });
  tearDown(() async => auth.dispose());

  Future<void> launch(
    WidgetTester tester, {
    double width = 390,
    double height = 844,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      DueWiseApp(
        authRepository: auth,
        profileRepository: profiles,
        activityRepository: activities,
        features: testFeatures(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String key, String label) async {
    await tapKey(tester, key);
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cadastrar, consultar, editar, concluir, reabrir e excluir atividade',
    (tester) async {
      await launch(tester);
      await tapKey(tester, 'new-activity');
      await tapKey(tester, 'save-activity');
      expect(find.text('Informe o título da atividade.'), findsOneWidget);
      expect(activities.activities, isEmpty);
      await tester.enterText(
        find.byKey(const Key('activity-title')),
        'Trabalho de Mobile',
      );
      await select(tester, 'activity-type', 'Trabalho');
      await select(tester, 'activity-priority', 'Alta');
      await tester.enterText(
        find.byKey(const Key('activity-description')),
        'Implementar SQLite',
      );
      await tapKey(tester, 'save-activity');
      final id = activities.activities.single.id;
      expect(activities.activities.single.type, ActivityType.assignment);
      expect(activities.activities.single.priority, ActivityPriority.high);
      await tapKey(tester, 'activity-$id');
      expect(find.text('Implementar SQLite'), findsOneWidget);
      await tapKey(tester, 'toggle-activity');
      expect(activities.activities.single.completed, isTrue);
      expect(find.text('Concluída'), findsOneWidget);
      await tapKey(tester, 'toggle-activity');
      expect(activities.activities.single.completed, isFalse);
      await tapKey(tester, 'edit-activity');
      await tester.enterText(
        find.byKey(const Key('activity-title')),
        'Trabalho revisado',
      );
      await tapKey(tester, 'save-activity');
      expect(activities.activities.single.id, id);
      expect(find.text('Trabalho revisado'), findsOneWidget);
      await tapKey(tester, 'delete-activity');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(activities.activities, hasLength(1));
      await tapKey(tester, 'delete-activity');
      await tapKey(tester, 'confirm-delete-activity');
      expect(activities.activities, isEmpty);
      expect(find.text('Atividade'), findsNothing);
    },
  );

  testWidgets(
    'filtros combinam tipo, conclusão e atraso sem confundir pendente com concluída',
    (tester) async {
      activities.activities.addAll([
        sample(id: 'exam', title: 'Prova futura'),
        sample(
          id: 'work',
          title: 'Trabalho concluído',
          type: ActivityType.assignment,
          completed: true,
        ),
        sample(
          id: 'late',
          title: 'Prova atrasada',
          dueAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ]);
      await launch(tester);
      await select(tester, 'filter-type', 'Prova');
      expect(find.text('Trabalho concluído'), findsNothing);
      await select(tester, 'filter-status', 'Concluídas');
      expect(
        find.text('Nenhuma atividade corresponde aos filtros.'),
        findsOneWidget,
      );
      await select(tester, 'filter-status', 'Pendentes');
      expect(find.text('Prova futura'), findsOneWidget);
      expect(find.text('Prova atrasada'), findsOneWidget);
      await select(tester, 'filter-status', 'Atrasadas');
      expect(find.text('Prova futura'), findsNothing);
      expect(find.text('Prova atrasada'), findsOneWidget);
      await select(tester, 'filter-type', 'Todos os tipos');
      await select(tester, 'filter-status', 'Todas as situações');
      expect(find.text('Trabalho concluído'), findsOneWidget);
    },
  );

  testWidgets('disciplina criada no formulário fica associada à atividade', (
    tester,
  ) async {
    await launch(tester);
    await tapKey(tester, 'new-activity');
    await tester.enterText(
      find.byKey(const Key('activity-title')),
      'Prova de DDM',
    );
    await tapKey(tester, 'new-discipline');
    await tester.enterText(
      find.byKey(const Key('discipline-name')),
      'Desenvolvimento Mobile',
    );
    await tapKey(tester, 'save-discipline');
    await tapKey(tester, 'save-activity');
    expect(activities.disciplines.single.name, 'Desenvolvimento Mobile');
    expect(
      activities.activities.single.disciplineId,
      activities.disciplines.single.id,
    );
    await tapKey(tester, 'activity-${activities.activities.single.id}');
    expect(find.text('Desenvolvimento Mobile'), findsOneWidget);
  });

  testWidgets(
    'falha ao cadastrar preserva formulário e permite repetir sem duplicar',
    (tester) async {
      await launch(tester);
      await tapKey(tester, 'new-activity');
      await tester.enterText(
        find.byKey(const Key('activity-title')),
        'Atividade importante',
      );
      activities.failWrites = true;
      await tapKey(tester, 'save-activity');
      expect(find.text('Falha de gravação para teste.'), findsOneWidget);
      expect(find.text('Nova atividade'), findsOneWidget);
      expect(activities.activities, isEmpty);
      activities.failWrites = false;
      await tapKey(tester, 'save-activity');
      expect(activities.activities, hasLength(1));
    },
  );

  testWidgets('falha de exclusão mantém detalhes e registro', (tester) async {
    activities.activities.add(sample(id: 'a', title: 'Preservar atividade'));
    await launch(tester);
    await tapKey(tester, 'activity-a');
    activities.failWrites = true;
    await tapKey(tester, 'delete-activity');
    await tapKey(tester, 'confirm-delete-activity');
    expect(find.text('Falha de gravação para teste.'), findsOneWidget);
    expect(find.text('Atividade'), findsOneWidget);
    expect(activities.activities, hasLength(1));
  });

  testWidgets(
    'falha de leitura oferece nova tentativa sem apresentar um falso estado vazio',
    (tester) async {
      activities.failReads = true;
      await launch(tester);
      expect(find.text('Falha de leitura para teste.'), findsOneWidget);
      expect(find.byKey(const Key('new-activity')), findsNothing);
      activities.failReads = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('new-activity')), findsOneWidget);
    },
  );

  testWidgets(
    'troca de conta fecha detalhes e não mostra dados da conta anterior',
    (tester) async {
      activities.activities.addAll([
        sample(id: 'a', title: 'Privada da Ana'),
        sample(id: 'b', title: 'Privada do Bruno', userId: 'bruno'),
      ]);
      await launch(tester);
      await tapKey(tester, 'activity-a');
      auth.changeUser(
        const AppUser(id: 'bruno', email: 'bruno@example.com', name: 'Bruno'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Atividade'), findsNothing);
      expect(find.text('Privada da Ana'), findsNothing);
      expect(find.text('Privada do Bruno'), findsOneWidget);
    },
  );

  testWidgets('calendário mostra registros e criação usa o dia selecionado', (
    tester,
  ) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day, 12);
    activities.activities.add(
      sample(id: 'today', title: 'Atividade do dia', dueAt: day),
    );
    await launch(tester);
    await tester.tap(find.text('Calendário'));
    await tester.pumpAndSettle();
    final calendar = tester.widget<TableCalendar<AcademicActivity>>(
      find.byType(TableCalendar<AcademicActivity>),
    );
    expect(calendar.eventLoader!(day), hasLength(1));
    expect(find.text('Atividade do dia'), findsOneWidget);
    final selected = day.add(const Duration(days: 3));
    calendar.onDaySelected!(selected, selected);
    await tester.pumpAndSettle();
    expect(find.text('Atividade do dia'), findsNothing);
    await tapKey(tester, 'new-activity');
    expect(
      find.text(DateFormat('dd/MM/yyyy').format(selected)),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('activity-title')),
      'Atividade agendada',
    );
    await tapKey(tester, 'save-activity');
    expect(find.text('Atividade agendada'), findsOneWidget);
    final updatedCalendar = tester.widget<TableCalendar<AcademicActivity>>(
      find.byType(TableCalendar<AcademicActivity>),
    );
    expect(updatedCalendar.eventLoader!(selected), hasLength(1));
  });

  testWidgets('formulário funciona em tela pequena com teclado', (
    tester,
  ) async {
    await launch(tester, width: 320, height: 568);
    await tapKey(tester, 'new-activity');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('activity-title')),
      'Teste em tela pequena',
    );
    await tapKey(tester, 'save-activity');
    expect(activities.activities.single.title, 'Teste em tela pequena');
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumo considera pendências reais e atualiza após conclusão', (
    tester,
  ) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    activities.activities.addAll([
      sample(id: 'today', title: 'Pendente de hoje', dueAt: start),
      sample(
        id: 'yesterday',
        title: 'Atrasada de ontem',
        dueAt: start.subtract(const Duration(days: 1)),
      ),
      sample(
        id: 'tomorrow',
        title: 'Pendente de amanhã',
        dueAt: now.add(const Duration(days: 1)),
      ),
      sample(id: 'done', title: 'Já concluída', dueAt: start, completed: true),
    ]);
    await launch(tester);
    String count(int index) =>
        tester.widget<Text>(find.byKey(Key('summary-$index'))).data!;
    expect(count(0), '1');
    expect(count(1), '1');
    expect(count(2), '2');
    await tapKey(tester, 'complete-tomorrow');
    expect(count(1), '0');
    await tapKey(tester, 'complete-today');
    expect(count(0), '0');
    expect(count(2), '1');
  });

  testWidgets('edição abre com o título da atividade selecionada', (
    tester,
  ) async {
    activities.activities.add(
      sample(
        id: 'mobile',
        title: 'Trabalho final de Mobile',
        type: ActivityType.assignment,
      ),
    );
    await launch(tester);
    await tapKey(tester, 'activity-mobile');
    await tapKey(tester, 'edit-activity');
    final title = tester.widget<TextFormField>(
      find.byKey(const Key('activity-title')),
    );
    expect(title.controller!.text, 'Trabalho final de Mobile');
  });
}
