import '../models/student.dart';
import 'api_client.dart';
import 'public_api_client.dart';

class StudentService {
  StudentService(this._apiClient, this._publicApiClient);

  final ApiClient _apiClient;
  final PublicApiClient _publicApiClient;

  Future<List<Student>> fetchStudents({int? parentId, bool viaPublicServer = false}) async {
    // A parent's own children (or a student's own single row) live on the
    // Public Server (/students/me); /students is a director-only endpoint
    // on the local server that lists the whole school.
    if (parentId != null || viaPublicServer) {
      final data = await _publicApiClient.get('/students/me') as List<dynamic>;
      return data
          .map((item) => Student.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    final data = await _apiClient.get('/students') as List<dynamic>;
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
    String? username,
    String? password,
  }) async {
    final data =
        await _apiClient.multipartPost(
              '/students/director-create',
              fields: {
                'first_name': firstName,
                'last_name': lastName,
                'class_id': classId.toString(),
                'parent_phone': parentPhone,
                if (username != null && username.isNotEmpty) 'username': username,
                if (password != null && password.isNotEmpty) 'password': password,
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
    String? username,
    String? password,
  }) async {
    final fields = {
      'first_name': firstName,
      'last_name': lastName,
      'class_id': classId.toString(),
      'parent_phone': parentPhone,
      'is_active': isActive.toString(),
      if (username != null) 'username': username,
      if (password != null && password.isNotEmpty) 'password': password,
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
