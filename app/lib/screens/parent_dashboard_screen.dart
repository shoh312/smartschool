import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/student_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/student_tile.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final parentId = context.read<AuthProvider>().parentId;
      if (parentId != null) {
        context.read<StudentProvider>().loadStudents(parentId: parentId);
        context.read<NotificationProvider>().initialize(parentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentProvider>();
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.parentDashboard,
      actions: [
        IconButton(
          tooltip: l10n.notifications,
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.notifications),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          final parentId = context.read<AuthProvider>().parentId;
          await students.loadStudents(parentId: parentId);
        },
        child: students.isLoading
            ? const Center(child: CircularProgressIndicator())
            : students.students.isEmpty
            ? EmptyState(
                icon: Icons.family_restroom,
                title: l10n.noChildrenLinked,
                message: l10n.assignedStudentsWillAppear,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: students.students.length + 2,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Text(
                      l10n.children,
                      style: Theme.of(context).textTheme.titleLarge,
                    );
                  }
                  if (index == 1) {
                    return FilledButton.tonalIcon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.attendanceHistory,
                      ),
                      icon: const Icon(Icons.history),
                      label: Text(l10n.attendanceHistory),
                    );
                  }
                  return StudentTile(student: students.students[index - 2]);
                },
              ),
      ),
    );
  }
}
