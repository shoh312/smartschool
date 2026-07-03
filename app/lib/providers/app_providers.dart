import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../services/api_client.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/school_service.dart';
import '../services/student_service.dart';
import '../services/token_storage.dart';
import '../websocket/attendance_socket_service.dart';
import 'attendance_provider.dart';
import 'auth_provider.dart';
import 'language_provider.dart';
import 'notification_provider.dart';
import 'school_provider.dart';
import 'student_provider.dart';

List<SingleChildWidget> buildAppProviders() {
  return [
    Provider(create: (_) => TokenStorage()),
    // ... (rest of providers)
    ChangeNotifierProvider(create: (_) => LanguageProvider()),
    ProxyProvider<TokenStorage, ApiClient>(
      update: (_, storage, __) => ApiClient(tokenStorage: storage),
    ),
    ProxyProvider2<ApiClient, TokenStorage, AuthService>(
      update: (_, api, storage, __) => AuthService(api, storage),
    ),
    ProxyProvider<ApiClient, StudentService>(
      update: (_, api, __) => StudentService(api),
    ),
    ProxyProvider<ApiClient, AttendanceService>(
      update: (_, api, __) => AttendanceService(api),
    ),
    ProxyProvider<ApiClient, SchoolService>(
      update: (_, api, __) => SchoolService(api),
    ),
    ProxyProvider<ApiClient, NotificationService>(
      update: (_, api, __) => NotificationService(api),
    ),
    Provider(create: (_) => AttendanceSocketService()),
    ChangeNotifierProxyProvider2<AuthService, TokenStorage, AuthProvider>(
      create: (_) => AuthProvider(),
      update: (_, authService, storage, provider) =>
          (provider ?? AuthProvider())..attach(authService, storage),
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
  ];
}
