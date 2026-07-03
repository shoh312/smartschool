import '../models/camera_config.dart';
import '../models/school_class.dart';
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
}
