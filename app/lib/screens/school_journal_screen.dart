import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../providers/school_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
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
            ? const AppLoadingIndicator()
            : provider.classes.isEmpty
            ? EmptyState(
                icon: Icons.class_outlined,
                title: l10n.noClasses,
                message: l10n.createClassesMessage,
              )
            : ListView(
                padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
                children: [
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: MetricCard(
                            label: l10n.classes,
                            value: provider.classes.length.toString(),
                            icon: Icons.class_outlined,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricCard(
                            label: l10n.students,
                            value: students.length.toString(),
                            icon: Icons.groups_2_outlined,
                            color: context.colors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < provider.classes.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeSlideIn(
                        delay: i < 12 ? Duration(milliseconds: 40 * i) : Duration.zero,
                        child: AppListCard(
                          leading: AppListBadge(text: '${provider.classes[i].grade}'),
                          title: provider.classes[i].name,
                          subtitle:
                              '${studentCountByClass[provider.classes[i].id] ?? 0} ${l10n.students}',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClassJournalScreen(
                                classId: provider.classes[i].id,
                                className: provider.classes[i].name,
                              ),
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
