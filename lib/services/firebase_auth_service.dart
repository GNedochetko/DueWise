import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';

class FirebaseAuthService implements AuthRepository {
  FirebaseAuthService(this._auth);
  final FirebaseAuth _auth;

  AppUser? _mapUser(User? user) => user == null
      ? null
      : AppUser(
          id: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? '',
        );

  @override
  AppUser? get currentUser => _mapUser(_auth.currentUser);
  @override
  Stream<AppUser?> get userChanges => _auth.userChanges().map(_mapUser);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(messageForCode(error.code));
    }
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user!.updateDisplayName(name.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(messageForCode(error.code));
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // A resposta não revela se o endereço possui uma conta.
      if (error.code == 'user-not-found') return;
      throw AuthFailure(messageForCode(error.code));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(messageForCode(error.code));
    }
  }

  static String messageForCode(String code) => switch (code) {
    'invalid-credential' ||
    'invalid-login-credentials' ||
    'wrong-password' ||
    'user-not-found' => 'E-mail ou senha incorretos.',
    'invalid-email' => 'Informe um e-mail válido.',
    'email-already-in-use' =>
      'Este e-mail já está em uso. Entre ou recupere sua senha.',
    'weak-password' || 'password-does-not-meet-requirements' =>
      'A senha não atende aos requisitos. Use pelo menos 8 caracteres.',
    'network-request-failed' =>
      'Verifique sua conexão com a internet e tente novamente.',
    'too-many-requests' =>
      'Muitas tentativas. Aguarde um pouco e tente novamente.',
    'user-disabled' => 'Esta conta está desativada.',
    'operation-not-allowed' =>
      'O acesso por e-mail está indisponível no momento.',
    _ => 'Não foi possível concluir a operação. Tente novamente.',
  };
}
