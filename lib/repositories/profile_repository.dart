import '../models/app_user.dart';
import '../models/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> load(AppUser user);
  Future<void> save(UserProfile profile);
}

class ProfileFailure implements Exception {
  const ProfileFailure(this.message);
  final String message;
}
