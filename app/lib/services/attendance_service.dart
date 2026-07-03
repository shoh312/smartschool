import '../models/attendance.dart';
import 'api_client.dart';

class AttendanceService {
  AttendanceService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AttendanceRecord>> history({
    int? studentId,
    int? parentId,
    int limit = 100,
  }) async {
    final data =
        await _apiClient.get(
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
