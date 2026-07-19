import 'package:flutter/material.dart';

import '../screens/attendance_history_screen.dart';
import '../screens/camera_management_screen.dart';
import '../screens/class_management_screen.dart';
import '../screens/director_dashboard_screen.dart';
import '../screens/live_attendance_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/parent_dashboard_screen.dart';
import '../screens/school_journal_screen.dart';
import '../screens/student_details_screen.dart';
import '../screens/student_management_screen.dart';
import '../screens/teacher_dashboard_screen.dart';
import '../screens/teacher_management_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const main = '/main';
  static const directorDashboard = '/director';
  static const parentDashboard = '/parent';
  static const studentDetails = '/student';
  static const attendanceHistory = '/attendance-history';
  static const liveAttendance = '/live-attendance';
  static const cameras = '/cameras';
  static const classes = '/classes';
  static const notifications = '/notifications';
  static const students = '/students';
  static const teacherDashboard = '/teacher';
  static const teacherManagement = '/teachers';
  static const schoolJournal = '/school-journal';

  static Map<String, WidgetBuilder> get routes => {
    login: (_) => const LoginScreen(),
    main: (_) => const MainScreen(),
    directorDashboard: (_) => const DirectorDashboardScreen(),
    parentDashboard: (_) => const ParentDashboardScreen(),
    studentDetails: (_) => const StudentDetailsScreen(),
    attendanceHistory: (_) => const AttendanceHistoryScreen(),
    liveAttendance: (_) => const LiveAttendanceScreen(),
    cameras: (_) => const CameraManagementScreen(),
    classes: (_) => const ClassManagementScreen(),
    notifications: (_) => const NotificationScreen(),
    students: (_) => const StudentManagementScreen(),
    teacherDashboard: (_) => const TeacherDashboardScreen(),
    teacherManagement: (_) => const TeacherManagementScreen(),
    schoolJournal: (_) => const SchoolJournalScreen(),
  };
}
