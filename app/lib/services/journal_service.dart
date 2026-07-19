import '../models/grade.dart';
import 'api_client.dart';
import 'public_api_client.dart';

class JournalService {
  JournalService(this._apiClient, this._publicApiClient);

  final ApiClient _apiClient;
  final PublicApiClient _publicApiClient;

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
    int? parentId,
    int limit = 200,
  }) async {
    // parentId is a client-side routing signal only (never sent to the
    // server) -- a parent viewing their child's grades reads from the
    // Public Server; director/teacher views stay on the local server.
    final client = parentId != null ? _publicApiClient : _apiClient;
    final data =
        await client.get(
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
