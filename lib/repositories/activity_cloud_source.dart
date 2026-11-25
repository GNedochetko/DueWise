import '../models/academic_activity.dart';
import '../models/discipline.dart';
import '../models/pending_operation.dart';

class CloudActivityRecords {
  const CloudActivityRecords({
    this.activities = const [],
    this.disciplines = const [],
  });
  final List<AcademicActivity> activities;
  final List<Discipline> disciplines;
}

abstract interface class ActivityCloudSource {
  /// Eventos invalidam a leitura. O repositório consulta o cache mais recente,
  /// em vez de reaplicar payloads antigos de callbacks atrasados.
  Stream<void> watch(String userId);
  Future<CloudActivityRecords> readCache(String userId);

  /// Só conclui quando o servidor confirma a escrita ou exclusão.
  Future<void> apply(PendingOperation operation);
}

class CloudActivityFailure implements Exception {
  const CloudActivityFailure(this.message);
  final String message;
}

abstract interface class ConnectionMonitor {
  Future<bool> check();
  Stream<bool> get changes;
}
