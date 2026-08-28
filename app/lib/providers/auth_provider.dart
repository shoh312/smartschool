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

  /// Who is signed in, for the profile header. Written at login and
  /// restored with the session, so it survives a restart and needs no
  /// request of its own.
  String? displayName;
  String? displayDetail;

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
    displayName = await _storage?.readDisplayName();
    displayDetail = await _storage?.readDisplayDetail();
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
      await _refreshIdentity();
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
      await _refreshIdentity();
    });
  }

  /// True when this phone has no password yet and the caller should send
  /// them through the SMS-code flow. Only meaningful right after
  /// [loginParent] returned false without setting [error].
  bool parentNeedsPassword = false;

  Future<bool> loginParent(String phone, String password) async {
    parentNeedsPassword = false;
    return _run(() async {
      // Talks to the Public Server, not the local school network -- see
      // ParentAuthService. An unknown phone throws a normal ApiException
      // with a server-provided "ask your school" message, which _run's
      // catch below surfaces via `error` the same as any other login
      // failure.
      final outcome = await _parentAuthService!.loginParent(
        phone: phone,
        password: password,
      );
      if (outcome == ParentLoginOutcome.needsPassword) {
        parentNeedsPassword = true;
        // Not an error, but not a session either -- thrown so _run reports
        // false and the screen branches on parentNeedsPassword.
        throw const _NeedsPassword();
      }
      parentId = await _storage?.readParentId();
      role = AppRole.parent;
      teacherId = null;
      studentId = null;
      await _refreshIdentity();
    });
  }

  /// Finishes the code flow: stores the chosen password and signs in.
  Future<bool> completeParentSetup({
    required String setupToken,
    required String fullName,
    required String password,
  }) async {
    return _run(() async {
      parentId = await _parentAuthService!.setPassword(
        setupToken: setupToken,
        fullName: fullName,
        password: password,
      );
      role = AppRole.parent;
      teacherId = null;
      studentId = null;
      parentNeedsPassword = false;
      await _refreshIdentity();
    });
  }

  /// One form, two staff roles: the address alone does not say which, so
  /// the director table is tried first and the teacher table second. Both
  /// live on the school's own server, so this is two fast LAN calls rather
  /// than a round trip over the internet.
  Future<bool> loginStaff(String email, String password) async {
    final asDirector = await loginDirector(email, password);
    if (asDirector) return true;
    // Only a rejected credential is worth a second try; a server that could
    // not be reached would fail identically for the teacher endpoint.
    if (error != null && !_looksLikeBadCredentials(error!)) return false;
    return loginTeacher(email, password);
  }

  static bool _looksLikeBadCredentials(String message) =>
      message.contains('401') ||
      message.toLowerCase().contains('parol') ||
      message.toLowerCase().contains('credential');

  Future<bool> loginStudent(String username, String password) async {
    return _run(() async {
      studentId = await _studentAuthService!.loginStudent(username: username, password: password);
      role = AppRole.student;
      parentId = null;
      teacherId = null;
      await _refreshIdentity();
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
    displayName = null;
    displayDetail = null;
    notifyListeners();
  }

  /// Reads back what the login service just wrote. Each service stores the
  /// identity as part of saving the session, so this is the one place that
  /// knows it has landed -- reading it here keeps every login path the same
  /// shape instead of each returning a name of its own.
  Future<void> _refreshIdentity() async {
    displayName = await _storage?.readDisplayName();
    displayDetail = await _storage?.readDisplayDetail();
  }

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on _NeedsPassword {
      // Handled by the caller through parentNeedsPassword; nothing went
      // wrong, so no message is shown.
      return false;
    } catch (exception) {
      error = classifyError(exception);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

/// Internal signal, never shown: see AuthProvider.loginParent.
class _NeedsPassword implements Exception {
  const _NeedsPassword();
}
