import '../models/student.dart';
import 'api_client.dart';

class StudentService {
  StudentService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Student>> fetchStudents({int? parentId}) async {
    // Parents only have access to their own /students/me; /students is a
    // director-only endpoint that lists the whole school.
    final path = parentId != null ? '/students/me' : '/students';
    final data = await _apiClient.get(path) as List<dynamic>;
    return data
        .map((item) => Student.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Student> createStudent(Student student) async {
    final data =
        await _apiClient.post('/students', body: student.toCreateJson())
            as Map<String, dynamic>;
    return Student.fromJson(data);
  }

  Future<Student> createStudentWithFace({
    required String firstName,
    required String lastName,
    required int classId,
    required String parentPhone,
    required String imagePath,
  }) async {
    final data =
        await _apiClient.multipartPost(
              '/students/director-create',
              fields: {
                'first_name': firstName,
                'last_name': lastName,
                'class_id': classId.toString(),
                'parent_phone': parentPhone,
              },
              fileField: 'file',
              filePath: imagePath,
            )
            as Map<String, dynamic>;
    return Student.fromJson(data);
  }

  Future<Student> updateStudent({
    required int id,
    required String firstName,
    required String lastName,
    required int classId,
    required String parentPhone,
    required bool isActive,
    String? imagePath,
  }) async {
    final fields = {
      'first_name': firstName,
      'last_name': lastName,
      'class_id': classId.toString(),
      'parent_phone': parentPhone,
      'is_active': isActive.toString(),
    };

    if (imagePath != null) {
      final data = await _apiClient.multipartPost(
        '/students/$id',
        method: 'PUT',
        fields: fields,
        fileField: 'file',
        filePath: imagePath,
      ) as Map<String, dynamic>;
      return Student.fromJson(data);
    } else {
      final data = await _apiClient.put(
        '/students/$id',
        body: fields,
        isFormData: true,
      ) as Map<String, dynamic>;
      return Student.fromJson(data);
    }
  }

  Future<void> deleteStudent(int id) async {
    await _apiClient.delete('/students/$id');
  }
}
