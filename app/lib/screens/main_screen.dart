import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/director_nav_provider.dart';
import '../routes/app_routes.dart';
import '../screens/director_dashboard_screen.dart';
import '../screens/live_attendance_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/student_management_screen.dart';
import '../screens/class_management_screen.dart';
import '../screens/camera_management_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/teacher_management_screen.dart';
import '../widgets/director_bottom_nav.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  static const _pages = [
    DirectorDashboardScreen(isIntegrated: true),
    LiveAttendanceScreen(isIntegrated: true),
    _ManagementTab(),
    SettingsScreen(),
    NotificationScreen(isIntegrated: true),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.watch<DirectorNavProvider>().currentIndex;
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: DirectorBottomNav(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) =>
            context.read<DirectorNavProvider>().setIndex(index),
      ),
    );
  }
}

class _ManagementTab extends StatelessWidget {
  const _ManagementTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.manage),
          bottom: TabBar(
            isScrollable: true,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(text: l10n.students),
              Tab(text: l10n.classes),
              Tab(text: l10n.cameras),
              Tab(text: l10n.teachers),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            StudentManagementScreen(isIntegrated: true),
            ClassManagementScreen(isIntegrated: true),
            CameraManagementScreen(isIntegrated: true),
            TeacherManagementScreen(isIntegrated: true),
          ],
        ),
      ),
    );
  }
}
