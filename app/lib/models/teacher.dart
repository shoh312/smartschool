class Teacher {
  const Teacher({
    required this.id,
    required this.fullName,
    required this.email,
    this.schoolId,
    this.isActive = true,
  });

  final int id;
  final int? schoolId;
  final String fullName;
  final String email;
  final bool isActive;

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] as int,
      schoolId: json['school_id'] as int?,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
