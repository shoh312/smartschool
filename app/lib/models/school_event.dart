enum SchoolEventType { holiday, exam, test, event }

SchoolEventType schoolEventTypeFromString(String value) {
  switch (value) {
    case 'holiday':
      return SchoolEventType.holiday;
    case 'exam':
      return SchoolEventType.exam;
    case 'test':
      return SchoolEventType.test;
    default:
      return SchoolEventType.event;
  }
}

String schoolEventTypeToString(SchoolEventType type) {
  switch (type) {
    case SchoolEventType.holiday:
      return 'holiday';
    case SchoolEventType.exam:
      return 'exam';
    case SchoolEventType.test:
      return 'test';
    case SchoolEventType.event:
      return 'event';
  }
}

class SchoolEvent {
  const SchoolEvent({
    required this.id,
    required this.title,
    this.description,
    required this.eventType,
    required this.startDate,
    this.endDate,
    this.classId,
  });

  final int id;
  final String title;
  final String? description;
  final SchoolEventType eventType;
  final DateTime startDate;
  final DateTime? endDate;
  final int? classId;

  factory SchoolEvent.fromJson(Map<String, dynamic> json) => SchoolEvent(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        eventType: schoolEventTypeFromString(json['event_type'] as String? ?? 'event'),
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
        classId: json['class_id'] as int?,
      );
}
