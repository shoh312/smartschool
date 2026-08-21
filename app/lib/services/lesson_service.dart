import '../models/lesson_schedule.dart';
import 'api_client.dart';

class LessonService {
  LessonService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<LessonSlot>> fetchLessons(int classId) async {
    final data = await _apiClient.get('/lessons', query: {'class_id': classId.toString()}) as List<dynamic>;
    return data.map((item) => LessonSlot.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<LessonSlot> createLesson(LessonSlot lesson) async {
    final data = await _apiClient.post('/lessons', body: lesson.toJson()) as Map<String, dynamic>;
    return LessonSlot.fromJson(data);
  }

  Future<LessonSlot> updateLesson(int id, LessonSlot lesson) async {
    final data = await _apiClient.patch('/lessons/$id', body: lesson.toJson()) as Map<String, dynamic>;
    return LessonSlot.fromJson(data);
  }

  Future<void> deleteLesson(int id) async {
    await _apiClient.delete('/lessons/$id');
  }
}
