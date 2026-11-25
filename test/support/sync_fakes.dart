import 'dart:async';
import 'package:duewise/models/academic_activity.dart';
import 'package:duewise/models/discipline.dart';
import 'package:duewise/models/pending_operation.dart';
import 'package:duewise/repositories/activity_cloud_source.dart';

class TestConnectionMonitor implements ConnectionMonitor {
  TestConnectionMonitor(this.online);
  bool online;
  final events = StreamController<bool>.broadcast();
  void change(bool value) {
    online = value;
    events.add(value);
  }

  @override
  Future<bool> check() async => online;
  @override
  Stream<bool> get changes => events.stream;
  Future<void> dispose() => events.close();
}

class TestCloudSource implements ActivityCloudSource {
  final activities = <String, Map<String, AcademicActivity>>{};
  final disciplines = <String, Map<String, Discipline>>{};
  final calls = <PendingOperation>[];
  final gates = <Completer<void>>[];
  final events = StreamController<String>.broadcast();
  CloudActivityFailure? failure;
  bool failAfterCommitOnce = false;
  bool failCache = false;
  int concurrent = 0;
  int maximumConcurrent = 0;
  void notify(String userId) => events.add(userId);
  @override
  Stream<void> watch(String userId) =>
      events.stream.where((uid) => uid == userId).map((_) {});
  @override
  Future<CloudActivityRecords> readCache(String userId) async {
    if (failCache) throw const CloudActivityFailure('Falha ao ler cache.');
    return CloudActivityRecords(
      activities: activities[userId]?.values.toList() ?? [],
      disciplines: disciplines[userId]?.values.toList() ?? [],
    );
  }

  @override
  Future<void> apply(PendingOperation op) async {
    final callIndex = calls.length;
    calls.add(op);
    concurrent++;
    if (concurrent > maximumConcurrent) maximumConcurrent = concurrent;
    try {
      if (callIndex < gates.length) await gates[callIndex].future;
      if (failure != null) throw failure!;
      if (op.entity == SyncEntity.activity) {
        final records = activities[op.userId] ??= {};
        if (op.operation == SyncOperation.delete) {
          records.remove(op.id);
        } else {
          records[op.id] = AcademicActivity.fromMap(op.payload);
        }
      } else {
        final records = disciplines[op.userId] ??= {};
        if (op.operation == SyncOperation.delete) {
          records.remove(op.id);
        } else {
          records[op.id] = Discipline.fromMap(op.payload);
        }
      }
      notify(op.userId);
      if (failAfterCommitOnce) {
        failAfterCommitOnce = false;
        throw const CloudActivityFailure('Resposta perdida após a gravação.');
      }
    } finally {
      concurrent--;
    }
  }

  Future<void> dispose() => events.close();
}
