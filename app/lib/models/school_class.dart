class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.name,
    required this.grade,
  });

  final int id;
  final String name;
  final int grade;

  factory SchoolClass.fromJson(Map<String, dynamic> json) {
    return SchoolClass(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      grade: json['grade'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'grade': grade};
}
