import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/class_subject_assignment.dart';
import '../models/school_class.dart';
import '../providers/student_provider.dart';
import '../providers/teacher_admin_provider.dart';
import '../utils/error_formatter.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_card.dart';
import 'class_journal_screen.dart';

class ClassSubjectsScreen extends StatefulWidget {
  const ClassSubjectsScreen({super.key, required this.schoolClass});

  final SchoolClass schoolClass;

  @override
  State<ClassSubjectsScreen> createState() => _ClassSubjectsScreenState();
}

class _ClassSubjectsScreenState extends State<ClassSubjectsScreen> {
  int get classId => widget.schoolClass.id;
  String get className => widget.schoolClass.name;

  List<String> get _timetableSubjects {
    final subjects = <String>[];
    final seen = <String>{};
    for (final entries in widget.schoolClass.timetable.values) {
      for (final entry in entries) {
        final subject = entry.subject.trim();
        if (subject.isEmpty || seen.contains(subject)) {
          continue;
        }
        seen.add(subject);
        subjects.add(subject);
      }
    }
    subjects.sort();
    return subjects;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherAdminProvider>().loadClassSubjects(classId);
      context.read<StudentProvider>().loadStudents();
    });
  }

  Future<void> _openAssignTeacherDialog(
    String subject,
    ClassSubjectAssignment? currentAssignment,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TeacherAdminProvider>();
    int? pickedTeacherId = currentAssignment?.teacherId;

    provider.loadTeachersBySubject(subject);

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(subject),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.teachers,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Consumer<TeacherAdminProvider>(
                    builder: (context, provider, _) {
                      if (provider.isSubjectTeachersLoading) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (provider.subjectTeachers.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            l10n.noTeachersForSubject,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.colors.textSecondary),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final teacher in provider.subjectTeachers)
                            RadioListTile<int>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(teacher.fullName),
                              subtitle: Text(teacher.email),
                              value: teacher.id,
                              groupValue: pickedTeacherId,
                              onChanged: (value) =>
                                  setDialogState(() => pickedTeacherId = value),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: pickedTeacherId == null
                  ? null
                  : () async {
                      final success = await provider.assignClass(
                        teacherId: pickedTeacherId!,
                        classId: classId,
                        subject: subject,
                      );
                      if (context.mounted) Navigator.pop(context);
                      if (success) {
                        provider.loadClassSubjects(classId);
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.errorPrefix(
                                humanReadableError(provider.error, l10n),
                              ),
                            ),
                          ),
                        );
                      }
                    },
              child: Text(l10n.assign),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(int teacherId, int assignmentId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showAppConfirmDialog(
      context,
      icon: Icons.person_remove_outlined,
      title: l10n.removeAssignment,
      message: l10n.removeAssignmentConfirm,
      isDestructive: true,
    );

    if (!confirm || !mounted) return;

    final provider = context.read<TeacherAdminProvider>();
    final success = await provider.removeClassAssignment(
      teacherId: teacherId,
      assignmentId: assignmentId,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.errorPrefix(humanReadableError(provider.error, l10n)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TeacherAdminProvider>();
    final theme = Theme.of(context);
    final studentCount = context
        .watch<StudentProvider>()
        .students
        .where((student) => student.classId == classId)
        .length;
    final timetableSubjects = _timetableSubjects;
    final assignmentsBySubject = <String, ClassSubjectAssignment>{};
    for (final assignment in provider.classSubjects) {
      final subject = assignment.subject?.trim();
      if (subject == null || subject.isEmpty) continue;
      assignmentsBySubject[subject] = assignment;
    }
    final subjectCount = timetableSubjects.length;
    final teacherCount = assignmentsBySubject.values
        .map((assignment) => assignment.teacherId)
        .toSet()
        .length;
    final teacherAdminProvider = context.read<TeacherAdminProvider>();
    final studentProvider = context.read<StudentProvider>();

    return AppShell(
      title: className,
      actions: [
        IconButton(
          tooltip: l10n.viewJournal,
          icon: const Icon(Icons.menu_book_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ClassJournalScreen(classId: classId, className: className),
            ),
          ),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          await teacherAdminProvider.loadClassSubjects(classId);
          await studentProvider.loadStudents();
        },
        child: provider.isClassSubjectsLoading && provider.classSubjects.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: AppRadius.lgRadius,
                      boxShadow: AppShadows.colored(context.colors.primary),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: AppRadius.mdRadius,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.schoolClass.grade.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                className,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.gradeLabel(
                                  widget.schoolClass.grade.toString(),
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: MetricCard(
                            label: l10n.students,
                            value: studentCount.toString(),
                            icon: Icons.groups_2_outlined,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricCard(
                            label: l10n.subjectsLabel,
                            value: subjectCount.toString(),
                            icon: Icons.menu_book_outlined,
                            color: context.colors.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricCard(
                            label: l10n.teachers,
                            value: teacherCount.toString(),
                            icon: Icons.school_outlined,
                            color: context.colors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  DashboardSectionHeader(title: l10n.subjectsAndTeachers),
                  if (timetableSubjects.isEmpty)
                    SizedBox(
                      height: 220,
                      child: EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: l10n.noTimetableSubjectsTitle,
                        message: l10n.noTimetableSubjectsMessage,
                      ),
                    )
                  else
                    ...timetableSubjects.asMap().entries.map((entry) {
                      final subject = entry.value;
                      final assignment = assignmentsBySubject[subject];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FadeSlideIn(
                          delay: entry.key < 12
                              ? Duration(milliseconds: 40 * entry.key)
                              : Duration.zero,
                          child: AppListCard(
                            leading: const AppListBadge(icon: Icons.menu_book_outlined),
                            title: subject,
                            subtitle: assignment?.teacherName ?? l10n.tapToAssignTeacher,
                            onTap: () => _openAssignTeacherDialog(subject, assignment),
                            trailing: assignment == null
                                ? Icon(
                                    Icons.person_add_alt_1_outlined,
                                    color: context.colors.primary,
                                    size: 20,
                                  )
                                : IconButton(
                                    tooltip: l10n.removeAssignment,
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                      color: context.colors.danger,
                                    ),
                                    onPressed: () => _confirmRemove(
                                      assignment.teacherId,
                                      assignment.id,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }
}
