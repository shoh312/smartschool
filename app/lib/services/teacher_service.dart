import '../models/class_assignment.dart';
import '../models/class_subject_assignment.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import 'api_client.dart';

class TeacherService {
  TeacherService(this._apiClient);

  final ApiClient _apiClient;

  // Director-side management.

  Future<List<Teacher>> listTeachers({String? subject}) async {
    final data =
        await _apiClient.get(
              '/teachers',
              query: {if (subject != null) 'subject': subject},
            )
            as List<dynamic>;
    return data
        .map((item) => Teacher.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Teacher> createTeacher({
    required String fullName,
    required String email,
    required String password,
    String? subject,
  }) async {
    final data =
        await _apiClient.post(
              '/teachers',
              body: {
                'full_name': fullName,
                'email': email,
                'password': password,
                if (subject != null) 'subject': subject,
              },
            )
            as Map<String, dynamic>;
    return Teacher.fromJson(data);
  }

  Future<List<ClassSubjectAssignment>> classSubjects(int classId) async {
    final data =
        await _apiClient.get('/classes/$classId/subjects') as List<dynamic>;
    return data
        .map(
          (item) =>
              ClassSubjectAssignment.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> deleteTeacher(int teacherId) async {
    await _apiClient.delete('/teachers/$teacherId');
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

  Future<void> removeClassAssignment({
    required int teacherId,
    required int assignmentId,
  }) async {
    await _apiClient.delete('/teachers/$teacherId/classes/$assignmentId');
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
