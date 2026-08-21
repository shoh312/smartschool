class LessonSlot {
  const LessonSlot({
    required this.id,
    required this.classId,
    required this.subject,
    required this.dayOfWeek,
    required this.startTime,
    required this.durationMinutes,
    this.teacherId,
    this.room,
    this.teacherName,
  });

  final int id;
  final int classId;
  final String subject;
  final int dayOfWeek;
  final String startTime;
  final int durationMinutes;
  final int? teacherId;
  final String? room;
  final String? teacherName;

  factory LessonSlot.fromJson(Map<String, dynamic> json) => LessonSlot(
        id: json['id'] as int,
        classId: json['class_id'] as int,
        subject: json['subject'] as String? ?? '',
        dayOfWeek: json['day_of_week'] as int,
        startTime: json['start_time'] as String? ?? '',
        durationMinutes: json['duration_minutes'] as int? ?? 45,
        teacherId: json['teacher_id'] as int?,
        room: json['room'] as String?,
        teacherName: json['teacher_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'class_id': classId,
        'subject': subject,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'duration_minutes': durationMinutes,
        if (teacherId != null) 'teacher_id': teacherId,
        if (room != null) 'room': room,
      };
}

class DiaryEntry {
  const DiaryEntry({
    required this.lessonId,
    required this.subject,
    required this.startTime,
    required this.durationMinutes,
    this.room,
    this.teacherId,
    this.teacherName,
    this.homework,
    this.teacherComment,
    this.logDate,
    this.grade,
  });

  final int lessonId;
  final String subject;
  final String startTime;
  final int durationMinutes;
  final int? teacherId;
  final String? room;
  final String? teacherName;
  final String? homework;
  final String? teacherComment;

  /// The grade this student received in this lesson, when a parent or
  /// student (not a director/teacher) reads their own diary -- null for the
  /// class-wide teacher/director view, where a single grade wouldn't mean
  /// anything (every student in the class could have a different one).
  final int? grade;

  /// Only populated by the homework-list call (spans several days) --
  /// single-day diary screens already know the date from their own state
  /// and leave this null.
  final DateTime? logDate;

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
        lessonId: json['lesson_id'] as int,
        subject: json['subject'] as String? ?? '',
        startTime: json['start_time'] as String? ?? '',
        durationMinutes: json['duration_minutes'] as int? ?? 45,
        room: json['room'] as String?,
        teacherId: json['teacher_id'] as int?,
        teacherName: json['teacher_name'] as String?,
        homework: json['homework'] as String?,
        teacherComment: json['teacher_comment'] as String?,
        logDate: json['log_date'] != null ? DateTime.parse(json['log_date'] as String) : null,
        grade: json['grade'] as int?,
      );
}
