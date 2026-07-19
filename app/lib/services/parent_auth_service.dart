import '../models/app_role.dart';
import 'public_api_client.dart';
import 'token_storage.dart';

/// Parent login only -- talks to the Public Server, never the local
/// school-network backend (see AuthService for director/teacher, which stays
/// local-only). There is no self-registration branch here: a parent identity
/// can only originate from a director creating a student locally (trust
/// boundary), which then syncs in. An unknown phone throws a normal
/// ApiException with a clear "ask your school" message from the server,
/// which AuthProvider surfaces via its existing error-display path.
class ParentAuthService {
  ParentAuthService(this._apiClient, this._tokenStorage);

  final PublicApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<int> loginParent({required String phone}) async {
    final data =
        await _apiClient.post('/auth/login', body: {'phone': phone})
            as Map<String, dynamic>;

    final parentId = data['parent_id'] as int;
    await _tokenStorage.saveSession(
      token: data['access_token'] as String,
      role: AppRole.parent,
      parentId: parentId,
    );
    return parentId;
  }
}
