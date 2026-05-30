class Inspiration {
  final String id;
  final String title;
  final String? content;
  final bool isCompleted;
  final DateTime createdAt;

  const Inspiration({
    required this.id,
    required this.title,
    this.content,
    this.isCompleted = false,
    required this.createdAt,
  });

  factory Inspiration.fromJson(Map<String, dynamic> j) => Inspiration(
    id: j['id'] as String,
    title: j['title'] as String,
    content: j['content'] as String?,
    isCompleted: (j['is_completed'] as bool?) ?? false,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'is_completed': isCompleted,
    'created_at': createdAt.toIso8601String(),
  };

  Inspiration copyWith({String? title, String? content, bool? isCompleted}) => Inspiration(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    isCompleted: isCompleted ?? this.isCompleted,
    createdAt: createdAt,
  );
}
