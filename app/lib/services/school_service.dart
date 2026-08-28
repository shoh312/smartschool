import '../models/camera_config.dart';
import '../models/camera_position.dart';
import '../models/school_class.dart';
import '../models/school_settings.dart';
import 'api_client.dart';

class SchoolService {
  SchoolService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<SchoolClass>> fetchClasses() async {
    final data = await _apiClient.get('/classes') as List<dynamic>;
    return data
        .map((item) => SchoolClass.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SchoolClass> createClass(SchoolClass schoolClass) async {
    final data =
        await _apiClient.post('/classes', body: schoolClass.toJson())
            as Map<String, dynamic>;
    return SchoolClass.fromJson(data);
  }

  Future<SchoolClass> updateClass(SchoolClass schoolClass) async {
    final data =
        await _apiClient.put('/classes/${schoolClass.id}', body: schoolClass.toJson())
            as Map<String, dynamic>;
    return SchoolClass.fromJson(data);
  }

  Future<void> deleteClass(int id) async {
    await _apiClient.delete('/classes/$id');
  }

  Future<List<CameraConfig>> fetchCameras() async {
    final data = await _apiClient.get('/cameras') as List<dynamic>;
    return data
        .map((item) => CameraConfig.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CameraConfig> createCamera(CameraConfig camera) async {
    final data =
        await _apiClient.post('/cameras', body: camera.toJson())
            as Map<String, dynamic>;
    return CameraConfig.fromJson(data);
  }

  Future<CameraConfig> updateCamera(CameraConfig camera) async {
    final data =
        await _apiClient.put('/cameras/${camera.id}', body: camera.toJson())
            as Map<String, dynamic>;
    return CameraConfig.fromJson(data);
  }

  Future<void> deleteCamera(int id) async {
    await _apiClient.delete('/cameras/$id');
  }

  /// The camera watching one class, however it is attached.
  ///
  /// A school bolts a camera to a class; an academy bolts it to a room and
  /// lets the timetable say whose group is in front of it, so a group-mode
  /// camera carries no class id at all. Asking the server means the live
  /// view works in both without the app having to know which kind of school
  /// it is looking at.
  ///
  /// Returns null when nothing watches this class.
  Future<CameraConfig?> fetchCameraForClass(int classId) async {
    try {
      final data =
          await _apiClient.get('/classes/$classId/camera') as Map<String, dynamic>;
      return CameraConfig.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<List<CameraPosition>> fetchPositions(int cameraId) async {
    final data =
        await _apiClient.get('/cameras/$cameraId/positions') as List<dynamic>;
    return data
        .map((item) => CameraPosition.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Throws on an overlap -- the server refuses two groups in one room at one
  /// time rather than storing a schedule the camera cannot act on.
  Future<CameraPosition> createPosition({
    required int cameraId,
    required int classId,
    required String startTime,
    required String endTime,
    String? subject,
    int? dayOfWeek,
  }) async {
    final data = await _apiClient.post(
      '/cameras/$cameraId/positions',
      body: {
        'class_id': classId,
        'start_time': startTime,
        'end_time': endTime,
        if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
        if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      },
    ) as Map<String, dynamic>;
    return CameraPosition.fromJson(data);
  }

  Future<void> deletePosition(int cameraId, int positionId) async {
    await _apiClient.delete('/cameras/$cameraId/positions/$positionId');
  }

  Future<SchoolSettings> fetchSettings() async {
    final data = await _apiClient.get('/school/settings') as Map<String, dynamic>;
    return SchoolSettings.fromJson(data);
  }

  /// Sends only what changed -- the endpoint treats a missing field as "leave
  /// it alone", so two directors toggling different switches cannot undo each
  /// other.
  Future<SchoolSettings> updateSettings({
    bool? liveVideoEnabled,
    bool? groupMode,
  }) async {
    final data = await _apiClient.put(
      '/school/settings',
      body: {
        if (liveVideoEnabled != null) 'live_video_enabled': liveVideoEnabled,
        if (groupMode != null) 'group_mode': groupMode,
      },
    ) as Map<String, dynamic>;
    return SchoolSettings.fromJson(data);
  }
}
