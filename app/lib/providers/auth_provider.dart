import 'package:flutter/foundation.dart';

import '../models/app_role.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  AuthService? _authService;
  TokenStorage? _storage;

  AppRole? role;
  int? parentId;
  bool isLoading = false;
  String? error;

  void attach(AuthService authService, TokenStorage storage) {
    _authService = authService;
    _storage = storage;
  }

  Future<void> restoreSession() async {
    role = await _storage?.readRole();
    parentId = await _storage?.readParentId();
    notifyListeners();
  }

  Future<bool> loginDirector(String email, String password) async {
    return _run(() async {
      await _authService!.loginDirector(email: email, password: password);
      role = AppRole.director;
      parentId = null;
    });
  }

  Future<bool> loginParent(String phone) async {
    return _run(() async {
      final parentId = await _authService!.loginParent(phone: phone);
      if (parentId == -1) {
        throw 'registration_required';
      }
      this.parentId = parentId;
      role = AppRole.parent;
    });
  }

  Future<bool> registerParent(String phone, String fullName) async {
    return _run(() async {
      parentId = await _authService!.completeRegistration(phone: phone, fullName: fullName);
      role = AppRole.parent;
    });
  }

  Future<void> logout() async {
    await _authService?.logout();
    role = null;
    parentId = null;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (exception) {
      error = exception.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
