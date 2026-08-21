import '../models/notification_event.dart';
import 'api_client.dart';

class NotificationService {
  NotificationService(this._apiClient);

  final ApiClient _apiClient;

  /// Registers this device against whoever the bearer token belongs to.
  ///
  /// [parentId] is sent for backwards compatibility only -- the server
  /// takes the owner from the session, so the same call registers a pupil's
  /// own phone when a pupil is signed in.
  Future<void> saveDeviceToken({
    int? parentId,
    required String token,
    required String platform,
  }) async {
    await _apiClient.post('/notifications/device-token', body: {
      if (parentId != null) 'parent_id': parentId,
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
