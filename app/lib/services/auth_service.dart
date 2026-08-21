import '../models/app_role.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AuthService {
  AuthService(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  /// Returns true when the account is still on the default password and
  /// the app must send the director to the change form before anything else.
  Future<bool> loginDirector({
    required String email,
    required String password,
  }) async {
    final data =
        await _apiClient.post(
              '/auth/director/login',
              body: {'email': email, 'password': password},
            )
            as Map<String, dynamic>;

    await _tokenStorage.saveSession(
      token: data['access_token'] as String,
      role: AppRole.director,
    );
    return data['must_change_password'] as bool? ?? false;
  }

  /// Whether the signed-in director still has to change their password.
  /// Read from /auth/me so a restored session is checked too, not only a
  /// fresh login.
  Future<bool> directorMustChangePassword() async {
    try {
      final data = await _apiClient.get('/auth/me') as Map<String, dynamic>;
      return data['must_change_password'] as bool? ?? false;
    } catch (_) {
      // Offline or a stale token: let them in rather than stranding them
      // on a screen they can't complete.
      return false;
    }
  }

  Future<void> changeDirectorPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.post('/auth/director/change-password', body: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<void> loginTeacher({
    required String email,
    required String password,
  }) async {
    final data =
        await _apiClient.post(
              '/auth/teacher/login',
              body: {'email': email, 'password': password},
            )
            as Map<String, dynamic>;

    final teacher = data['teacher'] as Map<String, dynamic>;
    await _tokenStorage.saveSession(
      token: data['access_token'] as String,
      role: AppRole.teacher,
      teacherId: teacher['id'] as int,
    );
  }

  Future<int> completeRegistration({
    required String phone,
    required String fullName,
  }) async {
    final data = await _apiClient.post('/auth/register/complete', body: {
      'phone': phone,
      'full_name': fullName,
    }) as Map<String, dynamic>;

    final parentId = data['parent_id'] as int;
    await _tokenStorage.saveSession(
      token: data['access_token'] as String,
      role: AppRole.parent,
      parentId: parentId,
    );
    return parentId;
  }

  Future<void> logout() => _tokenStorage.clear();
}
