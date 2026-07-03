import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../screens/director_dashboard_screen.dart';
import '../screens/live_attendance_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/student_management_screen.dart';
import '../screens/class_management_screen.dart';
import '../screens/camera_management_screen.dart';
import '../screens/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DirectorDashboardScreen(isIntegrated: true),
    const LiveAttendanceScreen(isIntegrated: true),
    const _ManagementTab(),
    const SettingsScreen(),
    const NotificationScreen(isIntegrated: true),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        elevation: 10,
        height: 70,
        indicatorColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard_rounded, color: Color(0xFF6366F1)),
            label: l10n.dashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.videocam_outlined),
            selectedIcon: const Icon(Icons.videocam_rounded, color: Color(0xFF6366F1)),
            label: l10n.live,
          ),
          NavigationDestination(
            icon: const Icon(Icons.business_outlined),
            selectedIcon: const Icon(Icons.business_rounded, color: Color(0xFF6366F1)),
            label: l10n.manage,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded, color: Color(0xFF6366F1)),
            label: l10n.settings,
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications_rounded, color: Color(0xFF6366F1)),
            label: l10n.alerts,
          ),
        ],
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.manage),
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(text: l10n.students),
              Tab(text: l10n.classes),
              Tab(text: l10n.cameras),
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
          ],
        ),
      ),
    );
  }
}
