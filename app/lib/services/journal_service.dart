import '../models/grade.dart';
import '../models/homework.dart';
import 'api_client.dart';

class JournalService {
  JournalService(this._apiClient);

  final ApiClient _apiClient;

  Future<Grade> createGrade({
    required int studentId,
    required int classId,
    required String subject,
    required int value,
    String? comment,
    DateTime? gradeDate,
  }) async {
    final data =
        await _apiClient.post(
              '/grades',
              body: Grade.toCreateJson(
                studentId: studentId,
                classId: classId,
                subject: subject,
                value: value,
                comment: comment,
                gradeDate: gradeDate,
              ),
            )
            as Map<String, dynamic>;
    return Grade.fromJson(data);
  }

  Future<List<Grade>> listGrades({
    int? studentId,
    int? classId,
    int limit = 200,
  }) async {
    final data =
        await _apiClient.get(
              '/grades',
              query: {
                if (studentId != null) 'student_id': studentId.toString(),
                if (classId != null) 'class_id': classId.toString(),
                'limit': limit.toString(),
              },
            )
            as List<dynamic>;
    return data
        .map((item) => Grade.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Homework> createHomework({
    required int classId,
    required String subject,
    required String description,
    DateTime? dueDate,
  }) async {
    final data =
        await _apiClient.post(
              '/homework',
              body: Homework.toCreateJson(
                classId: classId,
                subject: subject,
                description: description,
                dueDate: dueDate,
              ),
            )
            as Map<String, dynamic>;
    return Homework.fromJson(data);
  }

  Future<List<Homework>> listHomework({
    int? studentId,
    int? classId,
    int limit = 100,
  }) async {
    final data =
        await _apiClient.get(
              '/homework',
              query: {
                if (studentId != null) 'student_id': studentId.toString(),
                if (classId != null) 'class_id': classId.toString(),
                'limit': limit.toString(),
              },
            )
            as List<dynamic>;
    return data
        .map((item) => Homework.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
