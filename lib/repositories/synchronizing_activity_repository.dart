import '../models/activity_sync_state.dart';
import 'activity_repository.dart';

abstract interface class SynchronizingActivityRepository
    implements ActivityRepository {
  Stream<ActivitySyncUpdate> watchSession(String userId);
  ActivitySyncUpdate snapshot(String userId);
  Future<void> startSession(String userId);
  Future<void> stopSession(String userId);
  Future<void> synchronize(String userId);
  Future<void> resume(String userId);
}
