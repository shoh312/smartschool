class ClassAssignment {
  const ClassAssignment({
    required this.id,
    required this.classId,
    this.subject,
    this.className,
  });

  final int id;
  final int classId;
  final String? subject;
  final String? className;

  factory ClassAssignment.fromJson(Map<String, dynamic> json) {
    return ClassAssignment(
      id: json['id'] as int,
      classId: json['class_id'] as int,
      subject: json['subject'] as String?,
      className: json['class_name'] as String?,
    );
  }
}
