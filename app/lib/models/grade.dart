class Grade {
  const Grade({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.teacherId,
    required this.subject,
    required this.value,
    required this.gradeDate,
    this.comment,
    this.teacherName,
  });

  final int id;
  final int studentId;
  final int classId;
  final int teacherId;
  final String subject;
  final int value;
  final String? comment;
  final DateTime gradeDate;
  final String? teacherName;

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: json['id'] as int,
      studentId: json['student_id'] as int,
      classId: json['class_id'] as int,
      teacherId: json['teacher_id'] as int,
      subject: json['subject'] as String? ?? '',
      value: json['value'] as int,
      comment: json['comment'] as String?,
      gradeDate: DateTime.parse(json['grade_date'] as String),
      teacherName: json['teacher_name'] as String?,
    );
  }

  static Map<String, dynamic> toCreateJson({
    required int studentId,
    required int classId,
    required String subject,
    required int value,
    String? comment,
    DateTime? gradeDate,
  }) {
    return {
      'student_id': studentId,
      'class_id': classId,
      'subject': subject,
      'value': value,
      'comment': comment,
      if (gradeDate != null)
        'grade_date':
            '${gradeDate.year.toString().padLeft(4, '0')}-${gradeDate.month.toString().padLeft(2, '0')}-${gradeDate.day.toString().padLeft(2, '0')}',
    };
  }
}
