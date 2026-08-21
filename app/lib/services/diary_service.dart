import '../models/lesson_schedule.dart';
import 'api_client.dart';
import 'public_api_client.dart';

class DiaryService {
  DiaryService(this._apiClient, this._publicApiClient);

  final ApiClient _apiClient;
  final PublicApiClient _publicApiClient;

  /// Director/teacher, viewing a class's diary on the local server. With
  /// [studentId] it narrows to that one pupil's diary -- same lessons and
  /// homework, plus their grades for the day.
  Future<List<DiaryEntry>> fetchClassDiary(int classId, DateTime on, {int? studentId}) async {
    final data = await _apiClient.get(
      '/diary',
      query: {
        'class_id': classId.toString(),
        'on': _dateOnly(on),
        if (studentId != null) 'student_id': studentId.toString(),
      },
    ) as List<dynamic>;
    return data.map((item) => DiaryEntry.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<DiaryEntry> updateDiaryLog(
    int lessonId,
    DateTime on, {
    String? homework,
    String? teacherComment,
  }) async {
    final data = await _apiClient.patch(
      '/diary/$lessonId',
      body: {
        if (homework != null) 'homework': homework,
        if (teacherComment != null) 'teacher_comment': teacherComment,
      },
    ) as Map<String, dynamic>;
    return DiaryEntry.fromJson(data);
  }

  /// Parent, reading their child's diary through the Public Server.
  Future<List<DiaryEntry>> fetchStudentDiary(int studentId, DateTime on) async {
    final data = await _publicApiClient.get(
      '/diary/$studentId',
      query: {'on': _dateOnly(on)},
    ) as List<dynamic>;
    return data.map((item) => DiaryEntry.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Parent or student, reading homework across several days (not just one
  /// day's diary) through the Public Server.
  Future<List<DiaryEntry>> fetchHomework(int studentId, {int days = 14}) async {
    final data = await _publicApiClient.get(
      '/diary/homework/$studentId',
      query: {'days': days.toString()},
    ) as List<dynamic>;
    return data.map((item) => DiaryEntry.fromJson(item as Map<String, dynamic>)).toList();
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
