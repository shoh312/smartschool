import '../models/school_event.dart';
import 'api_client.dart';
import 'public_api_client.dart';

class CalendarService {
  CalendarService(this._apiClient, this._publicApiClient);

  final ApiClient _apiClient;
  final PublicApiClient _publicApiClient;

  /// Director/teacher, school-scoped list on the local server.
  Future<List<SchoolEvent>> fetchEvents() async {
    final data = await _apiClient.get('/calendar/events') as List<dynamic>;
    return data.map((item) => SchoolEvent.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<SchoolEvent> createEvent({
    required String title,
    String? description,
    required SchoolEventType eventType,
    required DateTime startDate,
    DateTime? endDate,
    int? classId,
  }) async {
    final data = await _apiClient.post(
      '/calendar/events',
      body: {
        'title': title,
        'description': description,
        'event_type': schoolEventTypeToString(eventType),
        'start_date': _dateOnly(startDate),
        'end_date': endDate != null ? _dateOnly(endDate) : null,
        'class_id': classId,
      },
    ) as Map<String, dynamic>;
    return SchoolEvent.fromJson(data);
  }

  Future<void> deleteEvent(int id) async {
    await _apiClient.delete('/calendar/events/$id');
  }

  /// Parent, reading through the Public Server for their own child.
  Future<List<SchoolEvent>> fetchStudentEvents(int studentId) async {
    final data = await _publicApiClient.get(
      '/calendar/events',
      query: {'student_id': studentId.toString()},
    ) as List<dynamic>;
    return data.map((item) => SchoolEvent.fromJson(item as Map<String, dynamic>)).toList();
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
