import 'app_user.dart';

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.name,
    required this.email,
    this.course = '',
    this.institution = '',
  });

  factory UserProfile.fromUser(AppUser user) =>
      UserProfile(userId: user.id, name: user.name, email: user.email);

  final String userId;
  final String name;
  final String email;
  final String course;
  final String institution;
}
