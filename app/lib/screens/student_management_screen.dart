import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../providers/school_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/empty_state.dart';
import 'class_students_screen.dart';

/// Entry point for the director's "Students" tab -- lists the school's
/// classes (highest grade first) instead of every student mixed together;
/// tapping a class opens ClassStudentsScreen for just that classroom.
class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key, this.isIntegrated = false});

  final bool isIntegrated;

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents();
      context.read<SchoolProvider>().loadSchoolData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentProvider>();
    final school = context.watch<SchoolProvider>();
    final l10n = AppLocalizations.of(context)!;

    final countByClass = <int, int>{};
    for (final student in students.students) {
      final classId = student.classId;
      if (classId == null) continue;
      countByClass[classId] = (countByClass[classId] ?? 0) + 1;
    }

    final classes = List.of(school.classes)
      ..sort((a, b) {
        final byGrade = b.grade.compareTo(a.grade);
        return byGrade != 0 ? byGrade : a.name.compareTo(b.name);
      });

    return AppShell(
      title: l10n.studentManagement,
      showAppBar: !widget.isIntegrated,
      child: RefreshIndicator(
        onRefresh: () async {
          await students.loadStudents();
          await school.loadSchoolData();
        },
        child: classes.isEmpty && !school.isLoading
            ? SizedBox(
                height: 300,
                child: EmptyState(
                  icon: Icons.class_outlined,
                  title: l10n.noClasses,
                  message: l10n.createClassesMessage,
                ),
              )
            : ListView(
                padding: (const EdgeInsets.fromLTRB(16, 8, 16, 24)).add(bottomNavPadding(context)),
                children: [
                  DashboardSectionHeader(title: l10n.studentManagement),
                  for (var i = 0; i < classes.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeSlideIn(
                        delay: i < 12 ? Duration(milliseconds: 40 * i) : Duration.zero,
                        child: AppListCard(
                          leading: AppListBadge(text: '${classes[i].grade}'),
                          title: classes[i].name,
                          subtitle: '${countByClass[classes[i].id] ?? 0} ${l10n.students}',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClassStudentsScreen(
                                classId: classes[i].id,
                                className: classes[i].name,
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
