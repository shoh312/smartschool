import '../models/announcement.dart';
import 'api_client.dart';
import 'public_api_client.dart';

class AnnouncementService {
  AnnouncementService(this._apiClient, this._publicApiClient);

  final ApiClient _apiClient;
  final PublicApiClient _publicApiClient;

  /// Director/teacher, school-scoped list on the local server.
  Future<List<Announcement>> fetchAnnouncements() async {
    final data = await _apiClient.get('/announcements') as List<dynamic>;
    return data.map((item) => Announcement.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
    int? classId,
  }) async {
    final data = await _apiClient.post(
      '/announcements',
      body: {'title': title, 'body': body, 'class_id': classId},
    ) as Map<String, dynamic>;
    return Announcement.fromJson(data);
  }

  Future<void> deleteAnnouncement(int id) async {
    await _apiClient.delete('/announcements/$id');
  }

  /// Parent, reading through the Public Server for their own child.
  Future<List<Announcement>> fetchStudentAnnouncements(int studentId) async {
    final data = await _publicApiClient.get(
      '/announcements',
      query: {'student_id': studentId.toString()},
    ) as List<dynamic>;
    return data.map((item) => Announcement.fromJson(item as Map<String, dynamic>)).toList();
  }
}
