/// One lesson a pupil was not seen in.
///
/// Written by the cameras, not by a teacher: after the room has been swept
/// twice during a lesson and a pupil still has not appeared, the register
/// for that subject records them absent. It is undone automatically if they
/// walk in later in the same lesson.
class LessonAbsence {
  const LessonAbsence({
    required this.studentId,
    required this.subject,
    required this.date,
    required this.lessonId,
  });

  final int studentId;
  final String subject;
  final DateTime date;
  final int lessonId;

  factory LessonAbsence.fromJson(Map<String, dynamic> json) => LessonAbsence(
        studentId: json['student_id'] as int,
        subject: json['subject'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        lessonId: json['lesson_id'] as int? ?? 0,
      );
}
