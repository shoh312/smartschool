import '../models/app_role.dart';
import 'public_api_client.dart';
import 'token_storage.dart';

/// What the Public Server answered a parent's sign-in attempt with.
///
/// `needsPassword` is not a failure. Parents registered before passwords
/// existed have none stored, and there were 61 of them -- turning them away
/// would lock every one of those families out of the app. They are sent
/// through the same SMS-code flow a new parent uses, and come out the other
/// side with a password of their own.
enum ParentLoginOutcome { signedIn, needsPassword }

/// Parent authentication -- talks to the Public Server, never the local
/// school-network backend (see AuthService for director/teacher, which stays
/// local-only). There is no self-registration: a parent identity can only
/// originate from a director creating a student locally (trust boundary),
/// which then syncs in. An unknown phone throws a normal ApiException with a
/// clear "ask your school" message from the server.
class ParentAuthService {
  ParentAuthService(this._apiClient, this._tokenStorage);

  final PublicApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<ParentLoginOutcome> loginParent({
    required String phone,
    required String password,
  }) async {
    final data = await _apiClient.post(
      '/auth/login',
      body: {'phone': phone, 'password': password},
    ) as Map<String, dynamic>;

    if (data['status'] == 'needs_password') return ParentLoginOutcome.needsPassword;

    await _saveSession(data);
    return ParentLoginOutcome.signedIn;
  }

  /// Asks the server to text a code to a number it already knows.
  ///
  /// Returns whether the message actually left the gateway: until the school
  /// has an SMS contract the code is written to the server log instead, and
  /// the app has to tell the parent to ask the school rather than to wait
  /// for a message that is not coming.
  Future<({String maskedPhone, bool delivered, int expiresInSeconds})> requestCode({
    required String phone,
  }) async {
    final data = await _apiClient.post(
      '/auth/request-code',
      body: {'phone': phone},
    ) as Map<String, dynamic>;

    return (
      maskedPhone: data['phone_masked'] as String? ?? '',
      delivered: data['delivered'] as bool? ?? false,
      expiresInSeconds: data['expires_in_seconds'] as int? ?? 300,
    );
  }

  /// Returns a short-lived token proving this phone answered its code, and
  /// the name the school has on file so the next screen can offer it.
  Future<({String setupToken, String? fullName})> verifyCode({
    required String phone,
    required String code,
  }) async {
    final data = await _apiClient.post(
      '/auth/verify-code',
      body: {'phone': phone, 'code': code},
    ) as Map<String, dynamic>;

    return (
      setupToken: data['setup_token'] as String,
      fullName: data['full_name'] as String?,
    );
  }

  Future<int> setPassword({
    required String setupToken,
    required String fullName,
    required String password,
  }) async {
    final data = await _apiClient.post(
      '/auth/set-password',
      body: {
        'setup_token': setupToken,
        'full_name': fullName,
        'password': password,
      },
    ) as Map<String, dynamic>;

    return _saveSession(data);
  }

  Future<int> _saveSession(Map<String, dynamic> data) async {
    final parentId = data['parent_id'] as int;
    await _tokenStorage.saveSession(
      token: data['access_token'] as String,
      displayName: data['full_name'] as String?,
      displayDetail: data['phone'] as String?,
      role: AppRole.parent,
      parentId: parentId,
    );
    return parentId;
  }
}
