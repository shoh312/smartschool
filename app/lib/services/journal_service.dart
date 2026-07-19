import '../models/grade.dart';
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

  Future<Grade> updateGrade({
    required int gradeId,
    int? value,
    String? comment,
  }) async {
    final data =
        await _apiClient.patch(
              '/grades/$gradeId',
              body: {
                if (value != null) 'value': value,
                if (comment != null) 'comment': comment,
              },
            )
            as Map<String, dynamic>;
    return Grade.fromJson(data);
  }

  Future<void> deleteGrade(int gradeId) async {
    await _apiClient.delete('/grades/$gradeId');
  }

  Future<List<Grade>> listGrades({
    int? studentId,
    int? classId,
    String? subject,
    int limit = 200,
  }) async {
    final data =
        await _apiClient.get(
              '/grades',
              query: {
                if (studentId != null) 'student_id': studentId.toString(),
                if (classId != null) 'class_id': classId.toString(),
                if (subject != null && subject.isNotEmpty) 'subject': subject,
                'limit': limit.toString(),
              },
            )
            as List<dynamic>;
    return data
        .map((item) => Grade.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
