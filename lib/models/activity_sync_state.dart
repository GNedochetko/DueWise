import 'academic_activity.dart';
import 'discipline.dart';

class ActivitySyncState {
  const ActivitySyncState({
    this.pendingCount = 0,
    this.synchronizing = false,
    this.hasConnection = true,
    this.lastError,
  });
  final int pendingCount;
  final bool synchronizing;

  /// Indica disponibilidade de transporte, não confirmação de acesso ao servidor.
  final bool hasConnection;
  final String? lastError;
}

class ActivitySyncUpdate {
  const ActivitySyncUpdate({
    required this.activities,
    required this.disciplines,
    required this.state,
  });
  final List<AcademicActivity> activities;
  final List<Discipline> disciplines;
  final ActivitySyncState state;
}
