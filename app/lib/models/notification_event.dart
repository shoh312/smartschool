class NotificationEvent {
  const NotificationEvent({
    required this.id,
    required this.eventType,
    required this.title,
    required this.body,
    required this.status,
    this.parentId,
    this.studentId,
    this.attendanceId,
    this.createdAt,
  });

  final int id;
  final int? parentId;
  final int? studentId;
  final int? attendanceId;
  final String eventType;
  final String title;
  final String body;
  final String status;
  final DateTime? createdAt;

  factory NotificationEvent.fromJson(Map<String, dynamic> json) {
    return NotificationEvent(
      id: json['id'] as int,
      parentId: json['parent_id'] as int?,
      studentId: json['student_id'] as int?,
      attendanceId: json['attendance_id'] as int?,
      eventType: json['event_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
    );
  }
}
