import '../models/grade.dart';
import '../models/journal_scan_result.dart';
import 'api_client.dart';
import 'public_api_client.dart';

class JournalService {
  JournalService(this._apiClient, this._publicApiClient);

  final ApiClient _apiClient;
  final PublicApiClient _publicApiClient;

  /// Sends a photo of a paper journal page to be read via Gemini vision and
  /// matched against the class roster server-side. Returns candidates only
  /// -- nothing is written until the teacher reviews and confirms, at which
  /// point [createGrade] is called once per confirmed row (same as manual
  /// entry).
  Future<List<JournalScanResult>> scanJournalPhoto({
    required int classId,
    required String subject,
    required String imagePath,
  }) async {
    final data = await _apiClient.multipartPost(
      '/journal/scan-photo',
      fields: {'class_id': classId.toString(), 'subject': subject},
      fileField: 'file',
      filePath: imagePath,
    ) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>;
    return results.map((item) => JournalScanResult.fromJson(item as Map<String, dynamic>)).toList();
  }

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
    bool viaPublicServer = false,
    int limit = 200,
  }) async {
    // parentId/viaPublicServer are client-side routing signals only (never
    // sent to the server) -- a parent or a student viewing their own grades
    // reads from the Public Server; director/teacher views stay on the
    // local server.
    final client = (parentId != null || viaPublicServer) ? _publicApiClient : _apiClient;
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
