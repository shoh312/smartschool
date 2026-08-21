import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_role.dart';

class TokenStorage {
  static const _tokenKey = 'jwt_token';
  static const _roleKey = 'app_role';
  static const _parentIdKey = 'parent_id';
  static const _teacherIdKey = 'teacher_id';
  static const _studentIdKey = 'student_id';
  static const _serverUrlKey = 'server_base_url';
  // Kept apart from _serverUrlKey, which caches the auto-discovered school
  // server. This one is typed in by a person and must survive discovery
  // overwriting its own value.
  static const _publicServerUrlKey = 'public_server_base_url';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveSession({
    required String token,
    required AppRole role,
    int? parentId,
    int? teacherId,
    int? studentId,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role.name);
    if (parentId != null) {
      await _storage.write(key: _parentIdKey, value: parentId.toString());
    }
    if (teacherId != null) {
      await _storage.write(key: _teacherIdKey, value: teacherId.toString());
    }
    if (studentId != null) {
      await _storage.write(key: _studentIdKey, value: studentId.toString());
    }
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<AppRole?> readRole() async {
    final value = await _storage.read(key: _roleKey);
    if (value == null) return null;
    return AppRole.values.where((role) => role.name == value).firstOrNull;
  }

  Future<int?> readParentId() async {
    final value = await _storage.read(key: _parentIdKey);
    return value == null ? null : int.tryParse(value);
  }

  Future<int?> readTeacherId() async {
    final value = await _storage.read(key: _teacherIdKey);
    return value == null ? null : int.tryParse(value);
  }

  Future<int?> readStudentId() async {
    final value = await _storage.read(key: _studentIdKey);
    return value == null ? null : int.tryParse(value);
  }

  /// Last backend address that was reachable, kept across logout since it's
  /// network config, not auth state -- avoids re-discovering on every launch.
  Future<void> saveServerUrl(String url) =>
      _storage.write(key: _serverUrlKey, value: url);

  Future<String?> readServerUrl() => _storage.read(key: _serverUrlKey);

  Future<void> savePublicServerUrl(String? url) => (url == null || url.isEmpty)
      ? _storage.delete(key: _publicServerUrlKey)
      : _storage.write(key: _publicServerUrlKey, value: url);

  Future<String?> readPublicServerUrl() => _storage.read(key: _publicServerUrlKey);

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _parentIdKey);
    await _storage.delete(key: _teacherIdKey);
    await _storage.delete(key: _studentIdKey);
  }
}
