import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/student.dart';
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

  Future<void> _openGrades() async {
    final children = context.read<StudentProvider>().students;
    if (children.isEmpty) return;

    if (children.length == 1) {
      Navigator.pushNamed(
        context,
        AppRoutes.studentDetails,
        arguments: children.first,
      );
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<Student>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.children),
        children: [
          for (final child in children)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, child),
              child: Text(child.fullName),
            ),
        ],
      ),
    );

    if (selected != null && mounted) {
      Navigator.pushNamed(
        context,
        AppRoutes.studentDetails,
        arguments: selected,
      );
    }
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
                    return Row(
                      children: [
                        Expanded(
                          child: _ParentActionTile(
                            icon: Icons.history_rounded,
                            label: l10n.attendanceHistory,
                            color: AppColors.info,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.attendanceHistory,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ParentActionTile(
                            icon: Icons.grade_outlined,
                            label: l10n.grades,
                            color: AppColors.warning,
                            onTap: _openGrades,
                          ),
                        ),
                      ],
                    );
                  }
                  if (index == 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.children,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    );
                  }
                  return StudentTile(student: students.students[index - 2]);
                },
              ),
      ),
    );
  }
}

class _ParentActionTile extends StatelessWidget {
  const _ParentActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppGradients.tint(color),
                  borderRadius: AppRadius.mdRadius,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
