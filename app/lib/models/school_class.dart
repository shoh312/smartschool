class TimetableEntry {
  final String subject;
  final int durationMinutes;
  const TimetableEntry({required this.subject, this.durationMinutes = 45});
  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    return TimetableEntry(
      subject: json['subject'] as String? ?? '',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 45,
    );
  }
  Map<String, dynamic> toJson() => {
    'subject': subject,
    'duration_minutes': durationMinutes,
  };
}

class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.name,
    required this.grade,
    this.startTime,
    this.endTime,
    this.detectDurationSeconds,
    this.waitDurationMinutes,
    this.timetable = const {},
  });

  final int id;
  final String name;
  final int grade;
  final String? startTime;
  final String? endTime;
  final int? detectDurationSeconds;
  final int? waitDurationMinutes;
  final Map<String, List<TimetableEntry>> timetable;

  factory SchoolClass.fromJson(Map<String, dynamic> json) {
    final raw = json['timetable'] as Map<String, dynamic>?;
    return SchoolClass(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      grade: json['grade'] as int? ?? 0,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      detectDurationSeconds: json['detect_duration_seconds'] as int?,
      waitDurationMinutes: json['wait_duration_minutes'] as int?,
      timetable: raw == null
          ? {}
          : raw.map((day, entries) {
              final list = (entries as List<dynamic>)
                  .map((e) => TimetableEntry.fromJson(e as Map<String, dynamic>))
                  .toList();
              return MapEntry(day, list);
            }),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'grade': grade,
    'start_time': startTime,
    'end_time': endTime,
    'detect_duration_seconds': detectDurationSeconds,
    'wait_duration_minutes': waitDurationMinutes,
    'timetable': timetable.isEmpty
        ? null
        : timetable.map((day, entries) => MapEntry(day, entries.map((e) => e.toJson()).toList())),
  };

  double get totalWeeklyHours {
    double total = 0;
    for (final entries in timetable.values) {
      total += entries.fold(0, (sum, e) => sum + e.durationMinutes);
    }
    return total / 60;
  }

  double get hoursPerDay {
    // fallback if no timetable set
    if (timetable.isEmpty) return 6;
    return 0; // actual per-day calc done on backend
  }
}
