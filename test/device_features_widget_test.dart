import 'dart:convert';
import 'dart:io';
import 'package:duewise/app.dart';
import 'package:duewise/core/app_features.dart';
import 'package:duewise/models/app_user.dart';
import 'package:duewise/repositories/device_features.dart';
import 'package:flutter/material.dart';
import 'support/app_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;
  late MemoryActivityRepository activities;
  late FakeLocationService location;
  late FakeAddressLookup addresses;
  late MemoryPhotoRepository photos;
  late Directory directory;
  late String photo;
  setUpAll(loadAppFonts);
  setUp(() async {
    auth = FakeAuthRepository(initialUser: student);
    profiles = FakeProfileRepository();
    activities = MemoryActivityRepository();
    location = FakeLocationService();
    addresses = FakeAddressLookup();
    photos = MemoryPhotoRepository();
    directory = await Directory.systemTemp.createTemp('duewise-avatar-widget-');
    final file = File('${directory.path}/photo.png');
    await file.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jgL8AAAAASUVORK5CYII=',
      ),
    );
    photo = file.path;
  });
  tearDown(() async {
    await auth.dispose();
    await directory.delete(recursive: true);
  });
  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      DueWiseApp(
        authRepository: auth,
        profileRepository: profiles,
        activityRepository: activities,
        features: AppFeatures(
          location: location,
          addresses: addresses,
          photos: photos,
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

  Future<void> openAddress(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('address-section')));
    await tester.tap(find.text('Endereço (opcional)'));
    await tester.pumpAndSettle();
  }

  testWidgets('GPS e CEP entram na atividade, nos detalhes e na edição', (
    tester,
  ) async {
    await launch(tester);
    await tapKey(tester, 'new-activity');
    await tester.enterText(
      find.byKey(const Key('activity-title')),
      'Visita técnica',
    );
    await tapKey(tester, 'capture-location');
    expect(find.byKey(const Key('location-coordinates')), findsOneWidget);
    await openAddress(tester);
    await tester.enterText(find.byKey(const Key('address-cep')), '01001000');
    await tester.enterText(find.byKey(const Key('address-number')), '42');
    await tester.enterText(
      find.byKey(const Key('address-complement')),
      'Bloco B',
    );
    await tapKey(tester, 'lookup-cep');
    expect(addresses.requested, '01001000');
    await tapKey(tester, 'save-activity');
    final activity = activities.activities.single;
    expect(activity.latitude, -25.38);
    expect(activity.longitude, -51.46);
    expect(activity.address!.street, 'Praça da Sé');
    expect(activity.address!.number, '42');
    expect(activity.address!.complement, 'Bloco B');
    await tapKey(tester, 'activity-${activity.id}');
    expect(find.text('Coordenadas capturadas'), findsOneWidget);
    expect(find.textContaining('Bloco B'), findsOneWidget);
    await tester.ensureVisible(find.text('Coordenadas capturadas'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'edit-activity');
    await tapKey(tester, 'remove-location');
    await tapKey(tester, 'save-activity');
    expect(activities.activities.single.latitude, isNull);
    expect(activities.activities.single.address!.number, '42');
  });

  testWidgets(
    'recusar GPS não bloqueia cadastro e permite abrir configurações',
    (tester) async {
      location.failure = const LocationFailure(
        'Permissão negada.',
        resolution: LocationResolution.appSettings,
      );
      await launch(tester);
      await tapKey(tester, 'new-activity');
      await tester.enterText(
        find.byKey(const Key('activity-title')),
        'Sem GPS',
      );
      await tapKey(tester, 'capture-location');
      expect(find.text('Permissão negada.'), findsOneWidget);
      await tapKey(tester, 'location-settings');
      expect(location.opened, LocationResolution.appSettings);
      await tapKey(tester, 'save-activity');
      expect(activities.activities.single.latitude, isNull);
    },
  );

  testWidgets('falha de CEP mantém preenchimento manual e permite salvar', (
    tester,
  ) async {
    addresses.failure = const AddressFailure(
      'Sem conexão. Preencha manualmente.',
    );
    await launch(tester);
    await tapKey(tester, 'new-activity');
    await tester.enterText(
      find.byKey(const Key('activity-title')),
      'Evento offline',
    );
    await openAddress(tester);
    await tester.enterText(find.byKey(const Key('address-cep')), '85000000');
    await tapKey(tester, 'lookup-cep');
    expect(find.text('Sem conexão. Preencha manualmente.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('address-street')),
      'Rua Manual',
    );
    await tester.enterText(find.byKey(const Key('address-city')), 'Guarapuava');
    await tester.enterText(find.byKey(const Key('address-state')), 'pr');
    await tapKey(tester, 'save-activity');
    expect(activities.activities.single.address!.street, 'Rua Manual');
    expect(activities.activities.single.address!.state, 'PR');
  });

  testWidgets(
    'foto pode ser selecionada, cancelada e removida sem alterar o perfil remoto',
    (tester) async {
      photos.selected = photo;
      await launch(tester);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'change-photo');
      await tapKey(tester, 'photo-gallery');
      expect(photos.lastSource, ProfilePhotoSource.gallery);
      expect(photos.paths[student.id], photo);
      expect(find.byKey(const Key('profile-photo')), findsOneWidget);
      expect(profiles.saved, isNull);
      photos.selected = null;
      await tapKey(tester, 'change-photo');
      await tapKey(tester, 'photo-camera');
      expect(photos.lastSource, ProfilePhotoSource.camera);
      expect(photos.paths[student.id], photo);
      await tapKey(tester, 'change-photo');
      await tapKey(tester, 'photo-remove');
      expect(photos.paths[student.id], isNull);
      expect(find.byKey(const Key('profile-photo')), findsNothing);
    },
  );

  testWidgets(
    'falha na seleção mantém foto anterior e não impede salvar nome e curso',
    (tester) async {
      photos.paths[student.id] = photo;
      photos.failure = const PhotoFailure('Câmera indisponível.');
      await launch(tester);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'change-photo');
      await tapKey(tester, 'photo-camera');
      expect(find.text('Câmera indisponível.'), findsOneWidget);
      expect(find.byKey(const Key('profile-photo')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('profile-course')),
        'Computação',
      );
      await tapKey(tester, 'save-profile');
      expect(profiles.saved!.course, 'Computação');
    },
  );

  testWidgets('foto de uma conta não aparece ao trocar de usuário', (
    tester,
  ) async {
    photos.paths[student.id] = photo;
    await launch(tester);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-photo')), findsOneWidget);
    auth.changeUser(
      const AppUser(id: 'bruno', email: 'bruno@example.com', name: 'Bruno'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-photo')), findsNothing);
    expect(photos.paths[student.id], photo);
  });
}
