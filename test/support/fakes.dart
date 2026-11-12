import 'dart:async';
import 'package:duewise/models/app_user.dart';
import 'package:duewise/models/user_profile.dart';
import 'package:duewise/models/academic_activity.dart';
import 'package:duewise/models/discipline.dart';
import 'package:duewise/repositories/auth_repository.dart';
import 'package:duewise/repositories/profile_repository.dart';
import 'package:duewise/repositories/activity_repository.dart';

const student = AppUser(
  id: 'student-1',
  email: 'ana@example.com',
  name: 'Ana Silva',
);

/// Exclusivo dos testes. A aplicação distribuída sempre usa FirebaseAuthService.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? initialUser}) : _current = initialUser;
  AppUser? _current;
  final _changes = StreamController<AppUser?>.broadcast();
  int signInCalls = 0;
  int registerCalls = 0;
  String? lastEmail;
  String? lastName;
  String? resetEmail;
  AuthFailure? failure;
  Completer<void>? pendingSignIn;

  @override
  AppUser? get currentUser => _current;
  @override
  Stream<AppUser?> get userChanges async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    lastEmail = email;
    if (pendingSignIn != null) await pendingSignIn!.future;
    if (failure != null) throw failure!;
    _current = student;
    _changes.add(_current);
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    registerCalls++;
    lastName = name;
    lastEmail = email;
    if (failure != null) throw failure!;
    _current = AppUser(id: student.id, email: email, name: name);
    _changes.add(_current);
  }

  @override
  Future<void> resetPassword(String email) async {
    if (failure != null) throw failure!;
    resetEmail = email;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _changes.add(null);
  }

  void changeUser(AppUser? user) {
    _current = user;
    _changes.add(user);
  }

  Future<void> dispose() => _changes.close();
}

class FakeProfileRepository implements ProfileRepository {
  UserProfile? saved;
  ProfileFailure? loadFailure;
  ProfileFailure? saveFailure;
  @override
  Future<UserProfile> load(AppUser user) async {
    if (loadFailure != null) throw loadFailure!;
    return saved ?? UserProfile.fromUser(user);
  }

  @override
  Future<void> save(UserProfile profile) async {
    if (saveFailure != null) throw saveFailure!;
    saved = profile;
  }
}

class MemoryActivityRepository implements ActivityRepository {
  final activities = <AcademicActivity>[];
  final disciplines = <Discipline>[];
  bool failWrites = false;
  bool failReads = false;
  void _checkWrite() {
    if (failWrites)
      throw const ActivityFailure('Falha de gravação para teste.');
  }

  @override
  Future<List<AcademicActivity>> listActivities(String userId) async {
    if (failReads) throw const ActivityFailure('Falha de leitura para teste.');
    return activities.where((item) => item.userId == userId).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  @override
  Future<AcademicActivity?> findActivity(String userId, String id) async {
    for (final item in activities) {
      if (item.userId == userId && item.id == id) return item;
    }
    return null;
  }

  @override
  Future<void> insertActivity(AcademicActivity activity) async {
    _checkWrite();
    activities.add(activity);
  }

  @override
  Future<void> updateActivity(AcademicActivity activity) async {
    _checkWrite();
    final index = activities.indexWhere(
      (item) => item.id == activity.id && item.userId == activity.userId,
    );
    if (index < 0) throw const ActivityFailure('Atividade não encontrada.');
    activities[index] = activity;
  }

  @override
  Future<void> setCompleted(
    String userId,
    String id,
    bool completed,
    DateTime updatedAt,
  ) async {
    _checkWrite();
    final index = activities.indexWhere(
      (item) => item.id == id && item.userId == userId,
    );
    if (index < 0) throw const ActivityFailure('Atividade não encontrada.');
    activities[index] = activities[index].withCompletion(completed, updatedAt);
  }

  @override
  Future<void> deleteActivity(String userId, String id) async {
    _checkWrite();
    activities.removeWhere((item) => item.id == id && item.userId == userId);
  }

  @override
  Future<List<Discipline>> listDisciplines(String userId) async =>
      disciplines.where((item) => item.userId == userId).toList();
  @override
  Future<void> insertDiscipline(Discipline discipline) async {
    _checkWrite();
    disciplines.add(discipline);
  }
}
