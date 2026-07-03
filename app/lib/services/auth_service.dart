import '../models/app_role.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AuthService {
  AuthService(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<void> loginDirector({
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
  }

  Future<int> loginParent({required String phone}) async {
    final data =
        await _apiClient.post('/auth/login', body: {'phone': phone})
            as Map<String, dynamic>;

    if (data['status'] == 'register') {
      return -1; // Special value indicating registration is needed
    }

    final parentId = data['parent_id'] as int;
    await _tokenStorage.saveSession(
      token: data['access_token'] as String,
      role: AppRole.parent,
      parentId: parentId,
    );
    return parentId;
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
