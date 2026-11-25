import 'package:http/http.dart' as http;
import '../repositories/device_features.dart';
import '../services/device_location_service.dart';
import '../services/local_profile_photo_service.dart';
import '../services/viacep_service.dart';

class AppFeatures {
  const AppFeatures({
    required this.location,
    required this.addresses,
    required this.photos,
  });
  factory AppFeatures.device() => AppFeatures(
    location: DeviceLocationService(),
    addresses: ViaCepService(http.Client()),
    photos: LocalProfilePhotoService(),
  );
  final LocationService location;
  final AddressLookup addresses;
  final ProfilePhotoRepository photos;
}
