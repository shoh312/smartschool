import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../services/api_client.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/journal_service.dart';
import '../services/notification_service.dart';
import '../services/parent_auth_service.dart';
import '../services/public_api_client.dart';
import '../services/school_service.dart';
import '../services/student_service.dart';
import '../services/teacher_service.dart';
import '../services/token_storage.dart';
import '../websocket/attendance_socket_service.dart';
import 'attendance_provider.dart';
import 'auth_provider.dart';
import 'director_nav_provider.dart';
import 'journal_provider.dart';
import 'language_provider.dart';
import 'notification_provider.dart';
import 'school_provider.dart';
import 'student_provider.dart';
import 'teacher_admin_provider.dart';
import 'teacher_provider.dart';
import 'theme_provider.dart';

List<SingleChildWidget> buildAppProviders() {
  return [
    Provider(create: (_) => TokenStorage()),
    // ... (rest of providers)
    ChangeNotifierProvider(create: (_) => LanguageProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => DirectorNavProvider()),
    ProxyProvider<TokenStorage, ApiClient>(
      update: (_, storage, __) => ApiClient(tokenStorage: storage),
    ),
    // A second, independently-injectable client pointed at the Public
    // Server -- only parent-facing services use this. Director/teacher
    // services keep using ApiClient (the auto-discovered local server)
    // above, unchanged.
    ProxyProvider<TokenStorage, PublicApiClient>(
      update: (_, storage, __) => PublicApiClient(tokenStorage: storage),
    ),
    ProxyProvider2<ApiClient, TokenStorage, AuthService>(
      update: (_, api, storage, __) => AuthService(api, storage),
    ),
    ProxyProvider2<PublicApiClient, TokenStorage, ParentAuthService>(
      update: (_, api, storage, __) => ParentAuthService(api, storage),
    ),
    ProxyProvider2<ApiClient, PublicApiClient, StudentService>(
      update: (_, api, publicApi, __) => StudentService(api, publicApi),
    ),
    ProxyProvider2<ApiClient, PublicApiClient, AttendanceService>(
      update: (_, api, publicApi, __) => AttendanceService(api, publicApi),
    ),
    ProxyProvider<ApiClient, SchoolService>(
      update: (_, api, __) => SchoolService(api),
    ),
    ProxyProvider<PublicApiClient, NotificationService>(
      update: (_, api, __) => NotificationService(api),
    ),
    ProxyProvider2<ApiClient, PublicApiClient, JournalService>(
      update: (_, api, publicApi, __) => JournalService(api, publicApi),
    ),
    ProxyProvider<ApiClient, TeacherService>(
      update: (_, api, __) => TeacherService(api),
    ),
    Provider(create: (_) => AttendanceSocketService()),
    ChangeNotifierProxyProvider3<
      AuthService,
      ParentAuthService,
      TokenStorage,
      AuthProvider
    >(
      create: (_) => AuthProvider(),
      update: (_, authService, parentAuthService, storage, provider) =>
          (provider ?? AuthProvider())
            ..attach(authService, parentAuthService, storage),
    ),
    ChangeNotifierProxyProvider<StudentService, StudentProvider>(
      create: (_) => StudentProvider(),
      update: (_, service, provider) =>
          (provider ?? StudentProvider())..attach(service),
    ),
    ChangeNotifierProxyProvider2<
      AttendanceService,
      AttendanceSocketService,
      AttendanceProvider
    >(
      create: (_) => AttendanceProvider(),
      update: (_, service, socket, provider) =>
          (provider ?? AttendanceProvider())..attach(service, socket),
    ),
    ChangeNotifierProxyProvider<SchoolService, SchoolProvider>(
      create: (_) => SchoolProvider(),
      update: (_, service, provider) =>
          (provider ?? SchoolProvider())..attach(service),
    ),
    ChangeNotifierProxyProvider<NotificationService, NotificationProvider>(
      create: (_) => NotificationProvider(),
      update: (_, service, provider) =>
          (provider ?? NotificationProvider())..attach(service),
    ),
    ChangeNotifierProxyProvider2<
      TeacherService,
      JournalService,
      TeacherProvider
    >(
      create: (_) => TeacherProvider(),
      update: (_, teacherService, journalService, provider) =>
          (provider ?? TeacherProvider())
            ..attach(teacherService, journalService),
    ),
    ChangeNotifierProxyProvider<TeacherService, TeacherAdminProvider>(
      create: (_) => TeacherAdminProvider(),
      update: (_, service, provider) =>
          (provider ?? TeacherAdminProvider())..attach(service),
    ),
    ChangeNotifierProxyProvider<JournalService, JournalProvider>(
      create: (_) => JournalProvider(),
      update: (_, service, provider) =>
          (provider ?? JournalProvider())..attach(service),
    ),
  ];
}
