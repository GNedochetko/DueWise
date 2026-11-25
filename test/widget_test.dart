import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:duewise/app.dart';
import 'package:duewise/models/academic_activity.dart';
import 'package:duewise/models/app_user.dart';
import 'package:duewise/main.dart';
import 'package:duewise/repositories/auth_repository.dart';
import 'package:duewise/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'support/app_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;
  late MemoryActivityRepository activities;

  setUpAll(loadAppFonts);

  setUp(() {
    auth = FakeAuthRepository();
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
      RepaintBoundary(
        key: const Key('preview'),
        child: DueWiseApp(
          authRepository: auth,
          profileRepository: profiles,
          activityRepository: activities,
          features: testFeatures(),
        ),
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

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'sem Firebase configurado apresenta estado explícito e não libera login',
    (tester) async {
      await tester.pumpWidget(
        DueWiseBootstrap(
          initializeFirebase: () async =>
              throw UnsupportedError('Configuração ausente'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Configuração inicial pendente'), findsOneWidget);
      expect(find.byKey(const Key('auth-submit')), findsNothing);
    },
  );

  testWidgets('campos inválidos não são enviados ao serviço', (tester) async {
    await launch(tester);
    await tapKey(tester, 'auth-submit');
    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
    expect(auth.signInCalls, 0);
    await tester.enterText(find.byKey(const Key('email')), 'email-invalido');
    await tapKey(tester, 'auth-submit');
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(auth.signInCalls, 0);
  });

  testWidgets('login abre início e logout remove acesso às telas internas', (
    tester,
  ) async {
    await launch(tester);
    await tester.enterText(find.byKey(const Key('email')), ' ana@example.com ');
    await tester.enterText(find.byKey(const Key('password')), 'minhasenha');
    await tapKey(tester, 'auth-submit');
    expect(auth.lastEmail, 'ana@example.com');
    expect(find.text('Olá, Ana'), findsOneWidget);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'sign-out');
    expect(find.byKey(const Key('auth-submit')), findsOneWidget);
    expect(find.text('Atividades'), findsNothing);
  });

  testWidgets('agenda identifica pelo e-mail a conta sem nome', (tester) async {
    auth.changeUser(
      const AppUser(id: 'sem-nome', email: 'aluno@example.com', name: ''),
    );
    await launch(tester);
    expect(find.text('Olá, aluno@example.com'), findsOneWidget);
  });

  testWidgets('credenciais recusadas preservam formulário e mostram erro', (
    tester,
  ) async {
    auth.failure = const AuthFailure('E-mail ou senha incorretos.');
    await launch(tester);
    await tester.enterText(find.byKey(const Key('email')), 'ana@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'incorreta');
    await tapKey(tester, 'auth-submit');
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(find.text('Atividades'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('auth-submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('requisição em andamento impede envio duplicado', (tester) async {
    auth.pendingSignIn = Completer<void>();
    await launch(tester);
    await tester.enterText(find.byKey(const Key('email')), 'ana@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'minhasenha');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('auth-submit')))
          .onPressed,
      isNull,
    );
    expect(auth.signInCalls, 1);
    auth.pendingSignIn!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Olá, Ana'), findsOneWidget);
  });

  testWidgets('cadastro exige senha suficiente e confirmação correspondente', (
    tester,
  ) async {
    await launch(tester);
    await tapKey(tester, 'open-register');
    await tester.enterText(find.byKey(const Key('name')), 'Ana Silva');
    await tester.enterText(find.byKey(const Key('email')), 'ana@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'curta');
    await tester.enterText(find.byKey(const Key('confirmation')), 'diferente');
    await tapKey(tester, 'auth-submit');
    expect(find.text('Use pelo menos 8 caracteres.'), findsWidgets);
    expect(find.text('As senhas não coincidem.'), findsOneWidget);
    expect(auth.registerCalls, 0);
    await tester.enterText(find.byKey(const Key('password')), 'senha1234');
    await tester.enterText(find.byKey(const Key('confirmation')), 'senha1234');
    await tapKey(tester, 'auth-submit');
    expect(auth.registerCalls, 1);
    expect(auth.lastName, 'Ana Silva');
    expect(find.text('Olá, Ana'), findsOneWidget);
  });

  testWidgets(
    'recuperação envia e-mail e mantém resposta sem expor existência da conta',
    (tester) async {
      await launch(tester);
      await tapKey(tester, 'open-reset');
      await tester.enterText(find.byKey(const Key('email')), 'ana@example.com');
      await tapKey(tester, 'auth-submit');
      expect(auth.resetEmail, 'ana@example.com');
      expect(find.textContaining('Se houver uma conta'), findsOneWidget);
      await tapKey(tester, 'back-login');
      expect(find.textContaining('Se houver uma conta'), findsNothing);
    },
  );

  testWidgets('sessão restaurada abre área interna diretamente', (
    tester,
  ) async {
    auth.changeUser(student);
    await launch(tester);
    expect(find.text('Olá, Ana'), findsOneWidget);
    expect(find.byKey(const Key('auth-submit')), findsNothing);
  });

  testWidgets('perfil salva nome curso e instituição no repositório', (
    tester,
  ) async {
    auth.changeUser(student);
    await launch(tester);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name')), 'Ana Souza');
    await tester.enterText(
      find.byKey(const Key('profile-course')),
      'Ciência da Computação',
    );
    await tester.enterText(
      find.byKey(const Key('profile-institution')),
      'UNICENTRO',
    );
    await tapKey(tester, 'save-profile');
    expect(profiles.saved?.userId, student.id);
    expect(profiles.saved?.name, 'Ana Souza');
    expect(profiles.saved?.course, 'Ciência da Computação');
    expect(profiles.saved?.institution, 'UNICENTRO');
    expect(find.text('Perfil salvo.'), findsOneWidget);
  });

  testWidgets('falha no perfil permite tentar novamente e sair da conta', (
    tester,
  ) async {
    auth.changeUser(student);
    profiles.loadFailure = const ProfileFailure(
      'Não foi possível carregar seu perfil.',
    );
    await launch(tester);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar seu perfil.'), findsOneWidget);
    profiles.loadFailure = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-course')), findsOneWidget);
  });

  testWidgets('falha ao salvar não mostra confirmação de sucesso', (
    tester,
  ) async {
    auth.changeUser(student);
    profiles.saveFailure = const ProfileFailure(
      'Não foi possível salvar seu perfil.',
    );
    await launch(tester);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'save-profile');
    expect(find.text('Não foi possível salvar seu perfil.'), findsOneWidget);
    expect(find.text('Perfil salvo.'), findsNothing);
    expect(profiles.saved, isNull);
  });

  testWidgets(
    'formulários cabem em tela pequena e permitem rolagem com teclado',
    (tester) async {
      await launch(tester, width: 320, height: 568);
      await tapKey(tester, 'open-register');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('auth-submit')));
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('auth-submit')).hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'telas preservam tema claro e navegação e geram prévias opcionais',
    (tester) async {
      final today = DateTime.now();
      activities.activities.add(
        AcademicActivity(
          id: 'mobile',
          userId: student.id,
          title: 'Trabalho final de Mobile',
          type: ActivityType.assignment,
          dueAt: DateTime(today.year, today.month, today.day, 23, 59),
          createdAt: today,
          updatedAt: today,
        ),
      );
      await launch(tester);
      final context = tester.element(find.byKey(const Key('auth-submit')));
      expect(Theme.of(context).brightness, Brightness.light);
      await capture(tester, 'login');
      await tester.enterText(find.byKey(const Key('email')), 'ana@example.com');
      await tester.enterText(find.byKey(const Key('password')), 'senha1234');
      await tapKey(tester, 'auth-submit');
      await capture(tester, 'inicio');
      await tester.tap(find.text('Calendário'));
      await tester.pumpAndSettle();
      await capture(tester, 'calendario');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-name')), findsOneWidget);
    },
  );
}
