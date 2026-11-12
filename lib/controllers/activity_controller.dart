import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/academic_activity.dart';
import '../models/discipline.dart';
import '../repositories/activity_repository.dart';

class ActivityController extends ChangeNotifier {
  ActivityController({required this.userId, required this.repository});
  final String userId;
  final ActivityRepository repository;
  final _uuid = const Uuid();
  final _savingIds = <String>{};
  List<AcademicActivity> _activities = [];
  List<Discipline> _disciplines = [];
  bool _disposed = false;
  bool loading = true;
  String? error;
  List<AcademicActivity> get activities => List.unmodifiable(_activities);
  List<Discipline> get disciplines => List.unmodifiable(_disciplines);
  bool isSaving(String id) => _savingIds.contains(id);
  String newId() => _uuid.v4();
  AcademicActivity? find(String id) {
    for (final activity in _activities) {
      if (activity.id == id) return activity;
    }
    return null;
  }

  Discipline? disciplineFor(String? id) {
    for (final discipline in _disciplines) {
      if (discipline.id == id) return discipline;
    }
    return null;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      final activities = await repository.listActivities(userId);
      final disciplines = await repository.listDisciplines(userId);
      if (_disposed) return;
      _activities = activities;
      _disciplines = disciplines;
    } on ActivityFailure catch (failure) {
      if (!_disposed) error = failure.message;
    } catch (_) {
      if (!_disposed)
        error = 'Não foi possível carregar suas atividades. Tente novamente.';
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> save(AcademicActivity activity, {required bool isNew}) async {
    _requireOwner(activity);
    await _mutate(activity.id, () async {
      if (isNew) {
        await repository.insertActivity(activity);
      } else {
        await repository.updateActivity(activity);
      }
      _activities.removeWhere((item) => item.id == activity.id);
      _activities.add(activity);
      _sort();
    });
  }

  Future<void> setCompleted(String id, bool completed) async {
    final activity = find(id);
    if (activity == null)
      throw const ActivityFailure('Atividade não encontrada.');
    await _mutate(id, () async {
      final now = DateTime.now();
      await repository.setCompleted(userId, id, completed, now);
      final index = _activities.indexWhere((item) => item.id == id);
      if (index >= 0)
        _activities[index] = activity.withCompletion(completed, now);
    });
  }

  Future<void> delete(String id) => _mutate(id, () async {
    await repository.deleteActivity(userId, id);
    _activities.removeWhere((item) => item.id == id);
  });
  Future<Discipline> createDiscipline(String name, int color) async {
    final discipline = Discipline(
      id: newId(),
      userId: userId,
      name: name.trim(),
      color: color,
    );
    await repository.insertDiscipline(discipline);
    _disciplines.add(discipline);
    _disciplines.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    _notify();
    return discipline;
  }

  Future<void> _mutate(String id, Future<void> Function() action) async {
    if (_savingIds.contains(id))
      throw const ActivityFailure('Aguarde a operação em andamento.');
    _savingIds.add(id);
    _notify();
    try {
      await action();
    } on ActivityFailure {
      rethrow;
    } catch (_) {
      throw const ActivityFailure(
        'Não foi possível salvar a alteração. Tente novamente.',
      );
    } finally {
      _savingIds.remove(id);
      _notify();
    }
  }

  void _requireOwner(AcademicActivity activity) {
    if (activity.userId != userId)
      throw const ActivityFailure('Atividade indisponível para esta conta.');
  }

  void _sort() => _activities.sort((a, b) => a.dueAt.compareTo(b.dueAt));
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
