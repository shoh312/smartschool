import 'package:flutter/foundation.dart';

import '../models/app_role.dart';
import '../services/auth_service.dart';
import '../services/parent_auth_service.dart';
import '../services/student_auth_service.dart';
import '../services/token_storage.dart';
import '../utils/error_formatter.dart';

class AuthProvider extends ChangeNotifier {
  AuthService? _authService;
  ParentAuthService? _parentAuthService;
  StudentAuthService? _studentAuthService;
  TokenStorage? _storage;

  AppRole? role;
  int? parentId;
  int? teacherId;
  int? studentId;
  bool isLoading = false;
  String? error;

  void attach(
    AuthService authService,
    ParentAuthService parentAuthService,
    StudentAuthService studentAuthService,
    TokenStorage storage,
  ) {
    _authService = authService;
    _parentAuthService = parentAuthService;
    _studentAuthService = studentAuthService;
    _storage = storage;
  }

  Future<void> restoreSession() async {
    role = await _storage?.readRole();
    parentId = await _storage?.readParentId();
    teacherId = await _storage?.readTeacherId();
    studentId = await _storage?.readStudentId();
    notifyListeners();
  }

  /// True while the director is still on the default password. The login
  /// screen sends them to the change form instead of the dashboard.
  bool mustChangePassword = false;

  Future<bool> loginDirector(String email, String password) async {
    return _run(() async {
      mustChangePassword =
          await _authService!.loginDirector(email: email, password: password);
      role = AppRole.director;
      parentId = null;
      teacherId = null;
      studentId = null;
    });
  }

  Future<void> refreshMustChangePassword() async {
    if (role != AppRole.director) {
      mustChangePassword = false;
      return;
    }
    mustChangePassword = await _authService!.directorMustChangePassword();
    notifyListeners();
  }

  Future<void> changeDirectorPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _authService!.changeDirectorPassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    mustChangePassword = false;
    notifyListeners();
  }

  Future<bool> loginTeacher(String email, String password) async {
    return _run(() async {
      await _authService!.loginTeacher(email: email, password: password);
      role = AppRole.teacher;
      parentId = null;
      studentId = null;
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
      teacherId = null;
      studentId = null;
    });
  }

  Future<bool> loginStudent(String username, String password) async {
    return _run(() async {
      studentId = await _studentAuthService!.loginStudent(username: username, password: password);
      role = AppRole.student;
      parentId = null;
      teacherId = null;
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
    studentId = null;
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
