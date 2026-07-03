import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_role.dart';

class TokenStorage {
  static const _tokenKey = 'jwt_token';
  static const _roleKey = 'app_role';
  static const _parentIdKey = 'parent_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveSession({
    required String token,
    required AppRole role,
    int? parentId,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role.name);
    if (parentId != null) {
      await _storage.write(key: _parentIdKey, value: parentId.toString());
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

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _parentIdKey);
  }
}
