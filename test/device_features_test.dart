import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:duewise/models/activity_address.dart';
import 'package:duewise/models/academic_activity.dart';
import 'package:duewise/models/pending_operation.dart';
import 'package:duewise/repositories/device_features.dart';
import 'package:duewise/services/device_location_service.dart';
import 'package:duewise/services/firestore_activity_service.dart';
import 'package:duewise/services/local_profile_photo_service.dart';
import 'package:duewise/services/viacep_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

class TestLocationGateway implements LocationGateway {
  bool isEnabled = true;
  LocationAccess access = LocationAccess.allowed;
  LocationAccess requestedAccess = LocationAccess.allowed;
  int requests = 0;
  int captures = 0;
  Object? failure;
  Coordinates coordinates = const Coordinates(-25.38, -51.46);
  LocationResolution? opened;
  @override
  Future<bool> enabled() async => isEnabled;
  @override
  Future<LocationAccess> check() async => access;
  @override
  Future<LocationAccess> request() async {
    requests++;
    return requestedAccess;
  }

  @override
  Future<Coordinates> position() async {
    captures++;
    if (failure != null) throw failure!;
    return coordinates;
  }

  @override
  Future<bool> openDeviceSettings() async {
    opened = LocationResolution.deviceSettings;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    opened = LocationResolution.appSettings;
    return true;
  }
}

class TestPhotoPicker implements PhotoPicker {
  XFile? selected;
  XFile? recovered;
  Completer<XFile?>? pending;
  PhotoFailure? failure;
  @override
  Future<XFile?> pick(ProfilePhotoSource source) async {
    if (failure != null) throw failure!;
    return pending == null ? selected : await pending!.future;
  }

  @override
  Future<XFile?> recover() async => recovered;
}

void main() {
  group('GPS', () {
    test('captura permitida retorna coordenadas', () async {
      final gateway = TestLocationGateway();
      final coordinates = await DeviceLocationService(gateway).capture();
      expect(coordinates.latitude, -25.38);
      expect(gateway.captures, 1);
      expect(gateway.requests, 0);
    });
    test('GPS desligado oferece configuração sem capturar posição', () async {
      final gateway = TestLocationGateway()..isEnabled = false;
      final service = DeviceLocationService(gateway);
      await expectLater(
        service.capture(),
        throwsA(
          isA<LocationFailure>().having(
            (e) => e.resolution,
            'resolução',
            LocationResolution.deviceSettings,
          ),
        ),
      );
      expect(gateway.captures, 0);
      await service.openSettings(LocationResolution.deviceSettings);
      expect(gateway.opened, LocationResolution.deviceSettings);
    });
    test(
      'permissão inicial é solicitada e recusa continua sem capturar',
      () async {
        final gateway = TestLocationGateway()
          ..access = LocationAccess.denied
          ..requestedAccess = LocationAccess.denied;
        await expectLater(
          DeviceLocationService(gateway).capture(),
          throwsA(isA<LocationFailure>()),
        );
        expect(gateway.requests, 1);
        expect(gateway.captures, 0);
        gateway.requestedAccess = LocationAccess.allowed;
        await DeviceLocationService(gateway).capture();
        expect(gateway.captures, 1);
      },
    );
    test(
      'recusa permanente direciona para as configurações do aplicativo',
      () async {
        final gateway = TestLocationGateway()
          ..access = LocationAccess.deniedForever;
        final service = DeviceLocationService(gateway);
        await expectLater(
          service.capture(),
          throwsA(
            isA<LocationFailure>().having(
              (e) => e.resolution,
              'resolução',
              LocationResolution.appSettings,
            ),
          ),
        );
        expect(gateway.requests, 0);
        expect(gateway.captures, 0);
        await service.openSettings(LocationResolution.appSettings);
        expect(gateway.opened, LocationResolution.appSettings);
      },
    );
    test(
      'tempo excedido e coordenadas inválidas geram falhas compreensíveis',
      () async {
        final gateway = TestLocationGateway()
          ..failure = TimeoutException('Sem sinal');
        await expectLater(
          DeviceLocationService(gateway).capture(),
          throwsA(isA<LocationFailure>()),
        );
        gateway.failure = null;
        gateway.coordinates = const Coordinates(100, double.nan);
        await expectLater(
          DeviceLocationService(gateway).capture(),
          throwsA(isA<LocationFailure>()),
        );
      },
    );
  });

  group('ViaCEP', () {
    Map<String, Object> valid() => {
      'logradouro': 'Praça da Sé',
      'bairro': 'Sé',
      'localidade': 'São Paulo',
      'uf': 'SP',
    };
    test('envia CEP normalizado e interpreta JSON com acentos', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://viacep.com.br/ws/01001000/json/',
        );
        return http.Response.bytes(utf8.encode(jsonEncode(valid())), 200);
      });
      addTearDown(client.close);
      final address = await ViaCepService(client).lookup('01001-000');
      expect(address.cep, '01001000');
      expect(address.street, 'Praça da Sé');
      expect(address.city, 'São Paulo');
    });
    test('CEP inválido não realiza requisição', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      });
      addTearDown(client.close);
      for (final cep in ['123', '01001a000', '123456789']) {
        await expectLater(
          ViaCepService(client).lookup(cep),
          throwsA(isA<AddressFailure>()),
        );
      }
      expect(calls, 0);
    });
    test('CEP inexistente, status HTTP e JSON inválido são tratados', () async {
      for (final response in [
        http.Response('{"erro":true}', 200),
        http.Response('{"erro":"true"}', 200),
        http.Response('Indisponível', 503),
        http.Response('invalido', 200),
        http.Response('[]', 200),
        http.Response('{}', 200),
      ]) {
        final client = MockClient((request) async => response);
        await expectLater(
          ViaCepService(client).lookup('01001000'),
          throwsA(isA<AddressFailure>()),
        );
        client.close();
      }
    });
    test('sem conexão e timeout não retornam um endereço fictício', () async {
      final offline = MockClient(
        (request) async => throw http.ClientException('Sem conexão'),
      );
      addTearDown(offline.close);
      await expectLater(
        ViaCepService(offline).lookup('01001000'),
        throwsA(isA<AddressFailure>()),
      );
      final slow = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{}', 200);
      });
      addTearDown(slow.close);
      await expectLater(
        ViaCepService(
          slow,
          timeout: const Duration(milliseconds: 1),
        ).lookup('01001000'),
        throwsA(isA<AddressFailure>()),
      );
    });
    test(
      'CEP de cidade sem logradouro continua permitindo preenchimento manual',
      () async {
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({'logradouro': '', 'localidade': 'Cidade', 'uf': 'PR'}),
            200,
          ),
        );
        addTearDown(client.close);
        final address = await ViaCepService(client).lookup('85000000');
        expect(address.street, isEmpty);
        expect(address.city, 'Cidade');
      },
    );
  });

  group('Fotos persistentes por usuário', () {
    late Directory directory;
    late TestPhotoPicker picker;
    late LocalProfilePhotoService service;
    late File original;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('duewise-photo-');
      original = File('${directory.path}/selected.png');
      await original.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jgL8AAAAASUVORK5CYII=',
        ),
      );
      picker = TestPhotoPicker()..selected = XFile(original.path);
      service = LocalProfilePhotoService(
        picker: picker,
        directory: () async => directory,
      );
    });
    tearDown(() async => directory.delete(recursive: true));
    test('copia do cache, reabre referência e separa contas', () async {
      final pathA = (await service.choose('u1', ProfilePhotoSource.gallery))!;
      final pathB = (await service.choose('u2', ProfilePhotoSource.camera))!;
      expect(pathA, isNot(pathB));
      expect(pathA, isNot(original.path));
      await original.delete();
      final reopened = LocalProfilePhotoService(
        picker: TestPhotoPicker(),
        directory: () async => directory,
      );
      expect(await reopened.load('u1'), pathA);
      expect(await reopened.load('u2'), pathB);
      expect(await File(pathA).exists(), isTrue);
      await reopened.remove('u1');
      expect(await reopened.load('u1'), isNull);
      expect(await File(pathA).exists(), isFalse);
      expect(await reopened.load('u2'), pathB);
    });
    test('cancelamento e falha de seleção mantêm a imagem anterior', () async {
      final previous = await service.choose('u1', ProfilePhotoSource.gallery);
      picker.selected = null;
      expect(await service.choose('u1', ProfilePhotoSource.gallery), isNull);
      expect(await service.load('u1'), previous);
      picker.failure = const PhotoFailure('Sem permissão');
      await expectLater(
        service.choose('u1', ProfilePhotoSource.camera),
        throwsA(isA<PhotoFailure>()),
      );
      expect(await service.load('u1'), previous);
    });
    test(
      'substituição limpa arquivo anterior sem apagar a imagem de origem',
      () async {
        final previous = (await service.choose(
          'u1',
          ProfilePhotoSource.gallery,
        ))!;
        final updated = (await service.choose(
          'u1',
          ProfilePhotoSource.gallery,
        ))!;
        expect(updated, isNot(previous));
        expect(await File(previous).exists(), isFalse);
        expect(await original.exists(), isTrue);
        expect(await service.load('u1'), updated);
      },
    );
    test(
      'recuperação após destruição da Activity respeita o UID original',
      () async {
        final root = Directory('${directory.path}/profile_photos');
        await root.create(recursive: true);
        await File(
          '${root.path}/pending_selection.json',
        ).writeAsString(jsonEncode({'userId': 'u1'}));
        picker.recovered = XFile(original.path);
        expect(await service.load('u2'), isNull);
        final recovered = await service.load('u1');
        expect(recovered, isNotNull);
        expect(await File(recovered!).exists(), isTrue);
        expect(
          await File('${root.path}/pending_selection.json').exists(),
          isFalse,
        );
      },
    );
    test('seleções simultâneas não disputam o seletor nativo', () async {
      picker.pending = Completer<XFile?>();
      final first = service.choose('u1', ProfilePhotoSource.gallery);
      await expectLater(
        service.choose('u2', ProfilePhotoSource.camera),
        throwsA(isA<PhotoFailure>()),
      );
      picker.pending!.complete(XFile(original.path));
      await first;
    });
  });

  test(
    'endereço e GPS sobrevivem à serialização e conclusão sem quebrar registros antigos',
    () {
      const address = ActivityAddress(
        cep: '01001000',
        street: 'Praça da Sé',
        city: 'São Paulo',
        state: 'SP',
        number: '10',
      );
      final model = AcademicActivity(
        id: 'a',
        userId: 'u1',
        title: 'Visita',
        type: ActivityType.technicalVisit,
        dueAt: DateTime(2026, 11, 20),
        createdAt: DateTime(2026, 11, 12),
        updatedAt: DateTime(2026, 11, 12),
        latitude: -25.38,
        longitude: -51.46,
        address: address,
      );
      final queued = AcademicActivity.fromMap(
        jsonDecode(jsonEncode(model.toMap())) as Map<String, dynamic>,
      );
      expect(queued.address!.number, '10');
      expect(queued.latitude, -25.38);
      expect(
        queued.withCompletion(true, DateTime.now()).address!.city,
        'São Paulo',
      );
      final op = PendingOperation(
        userId: 'u1',
        entity: SyncEntity.activity,
        id: 'a',
        operation: SyncOperation.upsert,
        payload: model.toMap(),
        revision: 'r',
        createdAt: 1,
      );
      final remote = FirestoreActivityService.encode(op);
      expect(
        FirestoreActivityService.decodeActivity('u1', 'a', remote).toMap(),
        model.toMap(),
      );
      remote.remove('address');
      expect(
        FirestoreActivityService.decodeActivity('u1', 'a', remote).address,
        isNull,
      );
      final old = model.toMap()..remove('address');
      expect(AcademicActivity.fromMap(old).address, isNull);
    },
  );
}
