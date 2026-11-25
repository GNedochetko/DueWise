import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/academic_activity.dart';
import '../models/activity_address.dart';
import '../models/discipline.dart';
import '../models/pending_operation.dart';
import '../repositories/activity_cloud_source.dart';

class FirestoreActivityService implements ActivityCloudSource {
  FirestoreActivityService(this.firestore);
  final FirebaseFirestore firestore;
  CollectionReference<Map<String, dynamic>> _activities(String uid) =>
      firestore.collection('users').doc(uid).collection('activities');
  CollectionReference<Map<String, dynamic>> _disciplines(String uid) =>
      firestore.collection('users').doc(uid).collection('disciplines');

  @override
  Stream<void> watch(String userId) {
    late StreamController<void> controller;
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    controller = StreamController<void>(
      onListen: () {
        for (final collection in [_activities(userId), _disciplines(userId)]) {
          subscriptions.add(
            collection
                .snapshots(includeMetadataChanges: true)
                .listen(
                  (_) => controller.add(null),
                  onError: (Object error) =>
                      controller.addError(_failure(error)),
                ),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  @override
  Future<CloudActivityRecords> readCache(String userId) async {
    try {
      final activities = await _activities(
        userId,
      ).get(const GetOptions(source: Source.cache));
      final disciplines = await _disciplines(
        userId,
      ).get(const GetOptions(source: Source.cache));
      return CloudActivityRecords(
        activities: activities.docs
            .map((doc) => decodeActivity(userId, doc.id, doc.data()))
            .toList(),
        disciplines: disciplines.docs
            .map((doc) => decodeDiscipline(userId, doc.id, doc.data()))
            .toList(),
      );
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> apply(PendingOperation operation) async {
    try {
      final collection = operation.entity == SyncEntity.activity
          ? _activities(operation.userId)
          : _disciplines(operation.userId);
      final reference = collection.doc(operation.id);
      if (operation.operation == SyncOperation.delete) {
        await reference.delete();
      } else {
        await reference.set(encode(operation));
      }
    } catch (error) {
      throw _failure(error);
    }
  }

  static Map<String, dynamic> encode(PendingOperation operation) {
    final payload = operation.payload;
    if (payload['user_id'] != operation.userId ||
        payload['id'] != operation.id) {
      throw const CloudActivityFailure('Os dados não pertencem a esta conta.');
    }
    final common = <String, dynamic>{
      'id': operation.id,
      'userId': operation.userId,
      'mutationId': operation.revision,
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    };
    if (operation.entity == SyncEntity.discipline) {
      final discipline = Discipline.fromMap(payload);
      return {...common, 'name': discipline.name, 'color': discipline.color};
    }
    final activity = AcademicActivity.fromMap(payload);
    return {
      ...common,
      'title': activity.title,
      'disciplineId': activity.disciplineId,
      'type': activity.type.name,
      'description': activity.description,
      'dueAt': Timestamp.fromDate(activity.dueAt),
      'priority': activity.priority.name,
      'completed': activity.completed,
      'location': activity.location,
      'latitude': activity.latitude,
      'longitude': activity.longitude,
      'address': activity.address?.toMap(),
      'createdAt': Timestamp.fromDate(activity.createdAt),
      'updatedAt': Timestamp.fromDate(activity.updatedAt),
    };
  }

  static AcademicActivity decodeActivity(
    String userId,
    String id,
    Map<String, dynamic> data,
  ) {
    _checkOwner(userId, id, data);
    return AcademicActivity(
      id: id,
      userId: userId,
      title: data['title'] as String,
      disciplineId: data['disciplineId'] as String?,
      type: ActivityType.values.byName(data['type'] as String),
      description: data['description'] as String,
      dueAt: (data['dueAt'] as Timestamp).toDate(),
      priority: ActivityPriority.values.byName(data['priority'] as String),
      completed: data['completed'] as bool,
      location: data['location'] as String,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      address: data['address'] is Map
          ? ActivityAddress.fromMap(
              Map<String, Object?>.from(data['address'] as Map),
            )
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  static Discipline decodeDiscipline(
    String userId,
    String id,
    Map<String, dynamic> data,
  ) {
    _checkOwner(userId, id, data);
    return Discipline(
      id: id,
      userId: userId,
      name: data['name'] as String,
      color: data['color'] as int,
    );
  }

  static void _checkOwner(String userId, String id, Map<String, dynamic> data) {
    if (data['userId'] != userId || data['id'] != id) {
      throw const CloudActivityFailure(
        'Não foi possível carregar os dados desta conta.',
      );
    }
  }

  static CloudActivityFailure _failure(Object error) {
    if (error is CloudActivityFailure) return error;
    if (error is FirebaseException) {
      return CloudActivityFailure(switch (error.code) {
        'permission-denied' =>
          'Não foi possível acessar a nuvem. Verifique as permissões do aplicativo.',
        'unauthenticated' =>
          'Entre novamente para sincronizar suas alterações.',
        'unavailable' || 'deadline-exceeded' =>
          'Não foi possível confirmar o envio. Suas alterações continuam salvas neste aparelho.',
        _ =>
          'Não foi possível sincronizar agora. Suas alterações continuam salvas neste aparelho.',
      });
    }
    return const CloudActivityFailure(
      'Não foi possível ler os dados da nuvem. As alterações locais foram preservadas.',
    );
  }
}
