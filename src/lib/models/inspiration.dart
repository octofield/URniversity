class Inspiration {
  final String id;
  final String title;
  final String? content;
  final DateTime createdAt;

  const Inspiration({
    required this.id,
    required this.title,
    this.content,
    required this.createdAt,
  });
}
