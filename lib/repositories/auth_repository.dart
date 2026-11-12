import '../models/app_user.dart';

/// As telas dependem deste contrato; em produção ele usa o Firebase.
abstract interface class AuthRepository {
  AppUser? get currentUser;
  Stream<AppUser?> get userChanges;
  Future<void> signIn({required String email, required String password});
  Future<void> register({
    required String name,
    required String email,
    required String password,
  });
  Future<void> resetPassword(String email);
  Future<void> signOut();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}
