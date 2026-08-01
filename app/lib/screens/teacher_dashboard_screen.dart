import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../providers/teacher_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import 'class_roster_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherProvider>().loadMyClasses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TeacherProvider>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.teacherMyClasses,
      child: RefreshIndicator(
        onRefresh: () => context.read<TeacherProvider>().loadMyClasses(),
        child: provider.isLoading && provider.myClasses.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.myClasses.isEmpty
            ? EmptyState(
                icon: Icons.school_outlined,
                title: l10n.teacherNoClassesTitle,
                message: l10n.teacherNoClassesMessage,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: provider.myClasses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final assignment = provider.myClasses[index];
                  final className = assignment.className ??
                      l10n.classFallbackLabel(assignment.classId.toString());
                  return Container(
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: AppRadius.lgRadius,
                      border: Border.all(color: context.colors.border),
                      boxShadow: AppShadows.card,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClassRosterScreen(
                              classId: assignment.classId,
                              className: className,
                              subject: assignment.subject ?? '',
                            ),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              borderRadius: AppRadius.mdRadius,
                              boxShadow: AppShadows.colored(context.colors.primary),
                            ),
                            child: const Icon(Icons.class_outlined, color: Colors.white, size: 22),
                          ),
                          title: Text(className, style: theme.textTheme.titleMedium),
                          subtitle: Text(assignment.subject ?? '-'),
                          trailing: Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
