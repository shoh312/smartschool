import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../providers/school_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_card.dart';
import 'class_journal_screen.dart';

class SchoolJournalScreen extends StatefulWidget {
  const SchoolJournalScreen({super.key});

  @override
  State<SchoolJournalScreen> createState() => _SchoolJournalScreenState();
}

class _SchoolJournalScreenState extends State<SchoolJournalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SchoolProvider>().loadSchoolData();
      context.read<StudentProvider>().loadStudents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final provider = context.watch<SchoolProvider>();
    final students = context.watch<StudentProvider>().students;

    final studentCountByClass = <int, int>{};
    for (final student in students) {
      final classId = student.classId;
      if (classId != null) {
        studentCountByClass[classId] = (studentCountByClass[classId] ?? 0) + 1;
      }
    }

    return AppShell(
      title: l10n.grades,
      child: RefreshIndicator(
        onRefresh: () async {
          await context.read<SchoolProvider>().loadSchoolData();
          await context.read<StudentProvider>().loadStudents();
        },
        child: provider.isLoading && provider.classes.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.classes.isEmpty
            ? EmptyState(
                icon: Icons.class_outlined,
                title: l10n.noClasses,
                message: l10n.createClassesMessage,
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: MetricCard(
                            label: l10n.classes,
                            value: provider.classes.length.toString(),
                            imageAsset: 'assets/icons/classes.png',
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricCard(
                            label: l10n.students,
                            value: students.length.toString(),
                            imageAsset: 'assets/icons/students.png',
                            color: context.colors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final schoolClass in provider.classes)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                              builder: (context) => ClassJournalScreen(
                                classId: schoolClass.id,
                                className: schoolClass.name,
                              ),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: AppGradients.tint(context.colors.accent),
                                borderRadius: AppRadius.mdRadius,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                schoolClass.grade.toString(),
                                style: TextStyle(
                                  color: context.colors.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            title: Text(
                              schoolClass.name,
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              '${studentCountByClass[schoolClass.id] ?? 0} ${l10n.students}',
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: context.colors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
