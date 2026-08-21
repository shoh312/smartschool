import '../models/app_role.dart';
import 'public_api_client.dart';
import 'token_storage.dart';

/// Student login only -- talks to the Public Server, never the local
/// school-network backend (mirrors ParentAuthService exactly: a student, like
/// a parent, needs to check things from home). A student's own username and
/// password are set once by a director on the local server, then synced.
class StudentAuthService {
  StudentAuthService(this._apiClient, this._tokenStorage);

  final PublicApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<int> loginStudent({required String username, required String password}) async {
    final data = await _apiClient.post(
      '/auth/student/login',
      body: {'username': username, 'password': password},
    ) as Map<String, dynamic>;

    final studentId = data['student_id'] as int;
    await _tokenStorage.saveSession(
      token: data['access_token'] as String,
      role: AppRole.student,
      studentId: studentId,
    );
    return studentId;
  }
}
