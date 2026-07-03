class Homework {
  const Homework({
    required this.id,
    required this.classId,
    required this.teacherId,
    required this.subject,
    required this.description,
    this.dueDate,
  });

  final int id;
  final int classId;
  final int teacherId;
  final String subject;
  final String description;
  final DateTime? dueDate;

  factory Homework.fromJson(Map<String, dynamic> json) {
    return Homework(
      id: json['id'] as int,
      classId: json['class_id'] as int,
      teacherId: json['teacher_id'] as int,
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
    );
  }

  static Map<String, dynamic> toCreateJson({
    required int classId,
    required String subject,
    required String description,
    DateTime? dueDate,
  }) {
    return {
      'class_id': classId,
      'subject': subject,
      'description': description,
      if (dueDate != null)
        'due_date':
            '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
    };
  }
}
