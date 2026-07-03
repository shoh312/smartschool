import '../models/notification_event.dart';
import 'api_client.dart';

class NotificationService {
  NotificationService(this._apiClient);

  final ApiClient _apiClient;

  Future<void> saveDeviceToken({
    required int parentId,
    required String token,
    required String platform,
  }) async {
    await _apiClient.post('/notifications/device-token', body: {
      'parent_id': parentId,
      'token': token,
      'platform': platform,
    });
  }

  Future<List<NotificationEvent>> parentNotifications(int parentId) async {
    final data =
        await _apiClient.get('/notifications/parent/$parentId')
            as List<dynamic>;
    return data
        .map((item) => NotificationEvent.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
