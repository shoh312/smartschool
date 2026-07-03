class Student {
  const Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.classId,
    this.parentId,
    this.className,
    this.parentPhone,
    this.photo,
    this.isActive = true,
  });

  final int id;
  final int? classId;
  final int? parentId;
  final String firstName;
  final String lastName;
  final String? className;
  final String? parentPhone;
  final String? photo;
  final bool isActive;

  String get fullName => '$firstName $lastName';

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as int,
      classId: json['class_id'] as int?,
      parentId: json['parent_id'] as int?,
      className: json['class_name'] as String?,
      parentPhone: json['parent_phone'] as String?,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      photo: json['photo'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'class_id': classId,
      'parent_id': parentId,
      'first_name': firstName,
      'last_name': lastName,
      'photo': photo,
    };
  }
}
