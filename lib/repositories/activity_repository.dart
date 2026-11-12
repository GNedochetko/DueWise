import '../models/academic_activity.dart';
import '../models/discipline.dart';

abstract interface class ActivityRepository {
  Future<List<AcademicActivity>> listActivities(String userId);
  Future<AcademicActivity?> findActivity(String userId, String id);
  Future<void> insertActivity(AcademicActivity activity);
  Future<void> updateActivity(AcademicActivity activity);
  Future<void> setCompleted(
    String userId,
    String id,
    bool completed,
    DateTime updatedAt,
  );
  Future<void> deleteActivity(String userId, String id);
  Future<List<Discipline>> listDisciplines(String userId);
  Future<void> insertDiscipline(Discipline discipline);
}

class ActivityFailure implements Exception {
  const ActivityFailure(this.message);
  final String message;
}
