class Discipline {
  const Discipline({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
  });
  factory Discipline.fromMap(Map<String, Object?> map) => Discipline(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    name: map['name'] as String,
    color: map['color'] as int,
  );
  final String id;
  final String userId;
  final String name;
  final int color;
  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'color': color,
  };
}
