enum ActivityType {
  exam('Prova'),
  assignment('Trabalho'),
  presentation('Apresentação'),
  event('Evento'),
  technicalVisit('Visita técnica');

  const ActivityType(this.label);
  final String label;
}

enum ActivityPriority {
  low('Baixa'),
  medium('Média'),
  high('Alta');

  const ActivityPriority(this.label);
  final String label;
}

enum ActivityStatus {
  pending('Pendentes'),
  completed('Concluídas'),
  overdue('Atrasadas');

  const ActivityStatus(this.label);
  final String label;
}

class AcademicActivity {
  const AcademicActivity({
    required this.id,
    required this.userId,
    required this.title,
    required this.type,
    required this.dueAt,
    required this.createdAt,
    required this.updatedAt,
    this.disciplineId,
    this.description = '',
    this.priority = ActivityPriority.medium,
    this.completed = false,
    this.location = '',
    this.latitude,
    this.longitude,
  });
  factory AcademicActivity.fromMap(
    Map<String, Object?> map,
  ) => AcademicActivity(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    title: map['title'] as String,
    disciplineId: map['discipline_id'] as String?,
    type: ActivityType.values.byName(map['type'] as String),
    description: map['description'] as String,
    dueAt: DateTime.fromMillisecondsSinceEpoch(map['due_at'] as int),
    priority: ActivityPriority.values.byName(map['priority'] as String),
    completed: map['completed'] == 1,
    location: map['location'] as String,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
  );
  final String id;
  final String userId;
  final String title;
  final String? disciplineId;
  final ActivityType type;
  final DateTime dueAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String description;
  final ActivityPriority priority;
  final bool completed;
  final String location;
  final double? latitude;
  final double? longitude;

  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'discipline_id': disciplineId,
    'type': type.name,
    'description': description,
    'due_at': dueAt.millisecondsSinceEpoch,
    'priority': priority.name,
    'completed': completed ? 1 : 0,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };
  AcademicActivity withCompletion(bool value, DateTime now) => AcademicActivity(
    id: id,
    userId: userId,
    title: title,
    disciplineId: disciplineId,
    type: type,
    dueAt: dueAt,
    createdAt: createdAt,
    updatedAt: now,
    description: description,
    priority: priority,
    completed: value,
    location: location,
    latitude: latitude,
    longitude: longitude,
  );
  bool isOverdueAt(DateTime now) => !completed && dueAt.isBefore(now);
  bool matchesStatus(ActivityStatus? status, DateTime now) => switch (status) {
    null => true,
    ActivityStatus.pending => !completed,
    ActivityStatus.completed => completed,
    ActivityStatus.overdue => isOverdueAt(now),
  };
}
