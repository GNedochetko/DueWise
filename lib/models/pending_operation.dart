import 'dart:convert';

enum SyncEntity { discipline, activity }

enum SyncOperation { upsert, delete }

class PendingOperation {
  const PendingOperation({
    required this.userId,
    required this.entity,
    required this.id,
    required this.operation,
    required this.payload,
    required this.revision,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });
  factory PendingOperation.fromMap(Map<String, Object?> map) =>
      PendingOperation(
        userId: map['user_id'] as String,
        entity: SyncEntity.values.byName(map['entity'] as String),
        id: map['record_id'] as String,
        operation: SyncOperation.values.byName(map['operation'] as String),
        payload: Map<String, Object?>.from(
          jsonDecode(map['payload'] as String) as Map,
        ),
        revision: map['revision'] as String,
        createdAt: map['created_at'] as int,
        attempts: map['attempts'] as int,
        lastError: map['last_error'] as String?,
      );
  final String userId;
  final SyncEntity entity;
  final String id;
  final SyncOperation operation;
  final Map<String, Object?> payload;
  final String revision;
  final int createdAt;
  final int attempts;
  final String? lastError;
  String get key => '${entity.name}/$id';
  Map<String, Object?> toMap() => {
    'user_id': userId,
    'entity': entity.name,
    'record_id': id,
    'operation': operation.name,
    'payload': jsonEncode(payload),
    'revision': revision,
    'created_at': createdAt,
    'attempts': attempts,
    'last_error': lastError,
  };
}
