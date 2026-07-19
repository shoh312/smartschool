class ClassSubjectAssignment {
  const ClassSubjectAssignment({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    this.subject,
  });

  final int id;
  final int teacherId;
  final String teacherName;
  final String? subject;

  factory ClassSubjectAssignment.fromJson(Map<String, dynamic> json) {
    return ClassSubjectAssignment(
      id: json['id'] as int,
      teacherId: json['teacher_id'] as int,
      teacherName: json['teacher_name'] as String? ?? '',
      subject: json['subject'] as String?,
    );
  }
}
