import 'package:image_picker/image_picker.dart';
import '../models/activity_address.dart';

class Coordinates {
  const Coordinates(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

enum LocationResolution { none, deviceSettings, appSettings }

class LocationFailure implements Exception {
  const LocationFailure(
    this.message, {
    this.resolution = LocationResolution.none,
  });
  final String message;
  final LocationResolution resolution;
}

abstract interface class LocationService {
  Future<Coordinates> capture();
  Future<void> openSettings(LocationResolution resolution);
}

abstract interface class AddressLookup {
  Future<ActivityAddress> lookup(String cep);
}

class AddressFailure implements Exception {
  const AddressFailure(this.message);
  final String message;
}

enum ProfilePhotoSource { gallery, camera }

abstract interface class ProfilePhotoRepository {
  Future<void> recoverLostSelection();
  Future<String?> load(String userId);
  Future<String?> choose(String userId, ProfilePhotoSource source);
  Future<void> remove(String userId);
}

abstract interface class PhotoPicker {
  Future<XFile?> pick(ProfilePhotoSource source);
  Future<XFile?> recover();
}

class PhotoFailure implements Exception {
  const PhotoFailure(this.message);
  final String message;
}
