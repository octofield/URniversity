class Journal {
  final String id;
  final DateTime date;
  final String? content;
  final DateTime createdAt;

  const Journal({
    required this.id,
    required this.date,
    this.content,
    required this.createdAt,
  });

  factory Journal.fromJson(Map<String, dynamic> j) => Journal(
    id: j['id'] as String,
    date: DateTime.parse(j['date'] as String),
    content: j['content'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'content': content,
    'created_at': createdAt.toIso8601String(),
  };

  Journal copyWith({DateTime? date, String? content}) => Journal(
    id: id,
    date: date ?? this.date,
    content: content ?? this.content,
    createdAt: createdAt,
  );
}
