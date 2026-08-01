import 'package:flutter/foundation.dart';

import '../models/app_role.dart';
import '../services/auth_service.dart';
import '../services/parent_auth_service.dart';
import '../services/token_storage.dart';
import '../utils/error_formatter.dart';

class AuthProvider extends ChangeNotifier {
  AuthService? _authService;
  ParentAuthService? _parentAuthService;
  TokenStorage? _storage;

  AppRole? role;
  int? parentId;
  int? teacherId;
  bool isLoading = false;
  String? error;

  void attach(
    AuthService authService,
    ParentAuthService parentAuthService,
    TokenStorage storage,
  ) {
    _authService = authService;
    _parentAuthService = parentAuthService;
    _storage = storage;
  }

  Future<void> restoreSession() async {
    role = await _storage?.readRole();
    parentId = await _storage?.readParentId();
    teacherId = await _storage?.readTeacherId();
    notifyListeners();
  }

  Future<bool> loginDirector(String email, String password) async {
    return _run(() async {
      await _authService!.loginDirector(email: email, password: password);
      role = AppRole.director;
      parentId = null;
      teacherId = null;
    });
  }

  Future<bool> loginTeacher(String email, String password) async {
    return _run(() async {
      await _authService!.loginTeacher(email: email, password: password);
      role = AppRole.teacher;
      parentId = null;
      teacherId = await _storage?.readTeacherId();
    });
  }

  Future<bool> loginParent(String phone) async {
    return _run(() async {
      // Talks to the Public Server, not the local school network -- see
      // ParentAuthService. An unknown phone throws a normal ApiException
      // with a server-provided "ask your school" message, which _run's
      // catch below surfaces via `error` the same as any other login
      // failure (no more separate self-registration branch).
      parentId = await _parentAuthService!.loginParent(phone: phone);
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
    teacherId = null;
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
      error = classifyError(exception);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
