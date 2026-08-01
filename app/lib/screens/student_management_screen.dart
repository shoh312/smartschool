import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../providers/school_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/app_shell.dart';
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
                padding: const EdgeInsets.all(16),
                children: [
                  for (final schoolClass in classes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
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
                                builder: (context) => ClassStudentsScreen(
                                  classId: schoolClass.id,
                                  className: schoolClass.name,
                                ),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: AppGradients.primary,
                                  borderRadius: AppRadius.mdRadius,
                                  boxShadow: AppShadows.colored(context.colors.primary),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  schoolClass.grade.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              title: Text(
                                schoolClass.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  '${countByClass[schoolClass.id] ?? 0} ${l10n.students}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: context.colors.textMuted,
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
