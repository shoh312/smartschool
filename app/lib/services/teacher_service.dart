import '../models/class_assignment.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import 'api_client.dart';

class TeacherService {
  TeacherService(this._apiClient);

  final ApiClient _apiClient;

  // Director-side management.

  Future<List<Teacher>> listTeachers() async {
    final data = await _apiClient.get('/teachers') as List<dynamic>;
    return data
        .map((item) => Teacher.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Teacher> createTeacher({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final data =
        await _apiClient.post(
              '/teachers',
              body: {
                'full_name': fullName,
                'email': email,
                'password': password,
              },
            )
            as Map<String, dynamic>;
    return Teacher.fromJson(data);
  }

  Future<ClassAssignment> assignClass({
    required int teacherId,
    required int classId,
    required String subject,
  }) async {
    final data =
        await _apiClient.post(
              '/teachers/$teacherId/classes',
              body: {'class_id': classId, 'subject': subject},
            )
            as Map<String, dynamic>;
    return ClassAssignment.fromJson(data);
  }

  // Teacher-side session.

  Future<List<ClassAssignment>> myClasses() async {
    final data = await _apiClient.get('/teachers/me/classes') as List<dynamic>;
    return data
        .map((item) => ClassAssignment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Student>> classRoster(int classId) async {
    final data =
        await _apiClient.get('/teachers/me/classes/$classId/students')
            as List<dynamic>;
    return data
        .map((item) => Student.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
