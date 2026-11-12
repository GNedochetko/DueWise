import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';

class FirestoreProfileService implements ProfileRepository {
  FirestoreProfileService(this._firestore);
  final FirebaseFirestore _firestore;
  static const _timeout = Duration(seconds: 15);

  @override
  Future<UserProfile> load(AppUser user) async {
    try {
      final document = await _firestore
          .collection('users')
          .doc(user.id)
          .get()
          .timeout(_timeout);
      final data = document.data();
      if (data == null) return UserProfile.fromUser(user);
      return UserProfile(
        userId: user.id,
        name: data['name'] as String? ?? user.name,
        email: user.email,
        course: data['course'] as String? ?? '',
        institution: data['institution'] as String? ?? '',
      );
    } on FirebaseException catch (_) {
      throw const ProfileFailure(
        'Não foi possível carregar seu perfil. Tente novamente.',
      );
    } on TimeoutException catch (_) {
      throw const ProfileFailure(
        'Não foi possível carregar seu perfil. Verifique sua conexão.',
      );
    }
  }

  @override
  Future<void> save(UserProfile profile) async {
    try {
      await _firestore
          .collection('users')
          .doc(profile.userId)
          .set({
            'name': profile.name.trim(),
            'email': profile.email,
            'course': profile.course.trim(),
            'institution': profile.institution.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(_timeout);
    } on FirebaseException catch (_) {
      throw const ProfileFailure(
        'Não foi possível salvar seu perfil. Tente novamente.',
      );
    } on TimeoutException catch (_) {
      throw const ProfileFailure(
        'Não foi possível confirmar o salvamento. Verifique sua conexão e tente novamente.',
      );
    }
  }
}
