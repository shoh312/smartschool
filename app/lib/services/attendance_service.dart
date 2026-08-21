import '../models/attendance.dart';
import 'api_client.dart';
import 'public_api_client.dart';

class AttendanceService {
  AttendanceService(this._apiClient, this._publicApiClient);

  final ApiClient _apiClient;
  final PublicApiClient _publicApiClient;

  Future<List<AttendanceRecord>> history({
    int? studentId,
    int? parentId,
    bool viaPublicServer = false,
    int limit = 100,
  }) async {
    // A parent's or a student's own attendance history lives on the Public
    // Server; director views (no parentId/viaPublicServer) stay on the
    // local, camera-derived data.
    final client = (parentId != null || viaPublicServer) ? _publicApiClient : _apiClient;
    final data =
        await client.get(
              '/attendance/history',
              query: {
                if (studentId != null) 'student_id': studentId.toString(),
                if (parentId != null) 'parent_id': parentId.toString(),
                'limit': limit.toString(),
              },
            )
            as List<dynamic>;
    return data
        .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<LiveAttendance>> liveStatus({int? classId}) async {
    final data =
        await _apiClient.get(
              '/attendance/live-status',
              query: {if (classId != null) 'class_id': classId.toString()},
            )
            as List<dynamic>;
    return data
        .map((item) => LiveAttendance.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
