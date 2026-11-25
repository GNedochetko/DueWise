import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../repositories/device_features.dart';

enum LocationAccess { denied, deniedForever, allowed }

abstract interface class LocationGateway {
  Future<bool> enabled();
  Future<LocationAccess> check();
  Future<LocationAccess> request();
  Future<Coordinates> position();
  Future<bool> openDeviceSettings();
  Future<bool> openAppSettings();
}

class GeolocatorGateway implements LocationGateway {
  LocationAccess _access(LocationPermission permission) => switch (permission) {
    LocationPermission.always ||
    LocationPermission.whileInUse => LocationAccess.allowed,
    LocationPermission.deniedForever => LocationAccess.deniedForever,
    _ => LocationAccess.denied,
  };
  @override
  Future<bool> enabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationAccess> check() async =>
      _access(await Geolocator.checkPermission());
  @override
  Future<LocationAccess> request() async =>
      _access(await Geolocator.requestPermission());
  @override
  Future<Coordinates> position() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return Coordinates(position.latitude, position.longitude);
  }

  @override
  Future<bool> openDeviceSettings() => Geolocator.openLocationSettings();
  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

class DeviceLocationService implements LocationService {
  DeviceLocationService([LocationGateway? gateway])
    : _gateway = gateway ?? GeolocatorGateway();
  final LocationGateway _gateway;
  @override
  Future<Coordinates> capture() async {
    try {
      if (!await _gateway.enabled()) {
        throw const LocationFailure(
          'Ative a localização do celular e tente novamente.',
          resolution: LocationResolution.deviceSettings,
        );
      }
      var access = await _gateway.check();
      if (access == LocationAccess.denied) access = await _gateway.request();
      if (access == LocationAccess.deniedForever) {
        throw const LocationFailure(
          'Permita o acesso à localização nas configurações do aplicativo.',
          resolution: LocationResolution.appSettings,
        );
      }
      if (access != LocationAccess.allowed) {
        throw const LocationFailure(
          'A localização não foi autorizada. Você pode salvar a atividade sem ela.',
        );
      }
      final coordinates = await _gateway.position().timeout(
        const Duration(seconds: 25),
      );
      if (!coordinates.latitude.isFinite ||
          !coordinates.longitude.isFinite ||
          coordinates.latitude.abs() > 90 ||
          coordinates.longitude.abs() > 180) {
        throw const LocationFailure(
          'Não foi possível obter uma localização válida. Tente novamente.',
        );
      }
      return coordinates;
    } on LocationFailure {
      rethrow;
    } on TimeoutException {
      throw const LocationFailure(
        'A localização demorou para responder. Tente novamente em um local com melhor sinal.',
      );
    } catch (_) {
      throw const LocationFailure(
        'Não foi possível obter sua localização. Tente novamente.',
      );
    }
  }

  @override
  Future<void> openSettings(LocationResolution resolution) async {
    try {
      final opened = switch (resolution) {
        LocationResolution.deviceSettings =>
          await _gateway.openDeviceSettings(),
        LocationResolution.appSettings => await _gateway.openAppSettings(),
        LocationResolution.none => true,
      };
      if (!opened) {
        throw const LocationFailure(
          'Abra as configurações do celular para ajustar a localização.',
        );
      }
    } on LocationFailure {
      rethrow;
    } catch (_) {
      throw const LocationFailure('Não foi possível abrir as configurações.');
    }
  }
}
