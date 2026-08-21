class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.createdAt,
    this.classId,
  });

  final int id;
  final String title;
  final String body;
  final DateTime? createdAt;
  final int? classId;

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: (json['created_at'] ?? json['created_at_local']) != null
            ? DateTime.parse((json['created_at'] ?? json['created_at_local']) as String)
            : null,
        classId: json['class_id'] as int?,
      );
}
