import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../models/school_class.dart';
import '../providers/student_provider.dart';
import '../providers/teacher_admin_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_card.dart';
import 'class_journal_screen.dart';

const List<Color> _kSubjectPalette = [
  AppColors.primary,
  AppColors.accent,
  AppColors.success,
  AppColors.warning,
  AppColors.info,
];

class ClassSubjectsScreen extends StatefulWidget {
  const ClassSubjectsScreen({super.key, required this.schoolClass});

  final SchoolClass schoolClass;

  @override
  State<ClassSubjectsScreen> createState() => _ClassSubjectsScreenState();
}

class _ClassSubjectsScreenState extends State<ClassSubjectsScreen> {
  int get classId => widget.schoolClass.id;
  String get className => widget.schoolClass.name;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherAdminProvider>().loadClassSubjects(classId);
      context.read<StudentProvider>().loadStudents();
    });
  }

  Future<void> _openAddSubjectDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TeacherAdminProvider>();
    String? pickedSubject;
    int? pickedTeacherId;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.addSubjectTitle),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.subjectLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final subject in AppConstants.schoolSubjects)
                        ChoiceChip(
                          label: Text(subject),
                          selected: subject == pickedSubject,
                          onSelected: (_) {
                            setDialogState(() {
                              pickedSubject = subject;
                              pickedTeacherId = null;
                            });
                            provider.loadTeachersBySubject(subject);
                          },
                        ),
                    ],
                  ),
                  if (pickedSubject != null) ...[
                    const SizedBox(height: 20),
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
                                  ?.copyWith(color: AppColors.textSecondary),
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
                                onChanged: (value) => setDialogState(
                                  () => pickedTeacherId = value,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
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
              onPressed: (pickedSubject == null || pickedTeacherId == null)
                  ? null
                  : () async {
                      final success = await provider.assignClass(
                        teacherId: pickedTeacherId!,
                        classId: classId,
                        subject: pickedSubject!,
                      );
                      if (context.mounted) Navigator.pop(context);
                      if (success) {
                        provider.loadClassSubjects(classId);
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.errorPrefix(provider.error ?? ''),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeAssignment),
        content: Text(l10n.removeAssignmentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<TeacherAdminProvider>();
    final success = await provider.removeClassAssignment(
      teacherId: teacherId,
      assignmentId: assignmentId,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorPrefix(provider.error ?? ''))),
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
    final subjectCount = provider.classSubjects.length;
    final teacherCount = provider.classSubjects
        .map((assignment) => assignment.teacherId)
        .toSet()
        .length;

    return AppShell(
      title: className,
      actions: [
        IconButton(
          tooltip: l10n.viewJournal,
          icon: const Icon(Icons.menu_book_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClassJournalScreen(
                classId: classId,
                className: className,
              ),
            ),
          ),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          await context.read<TeacherAdminProvider>().loadClassSubjects(
            classId,
          );
          await context.read<StudentProvider>().loadStudents();
        },
        child: provider.isClassSubjectsLoading && provider.classSubjects.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: AppRadius.lgRadius,
                      boxShadow: AppShadows.colored(AppColors.primary),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
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
                                  color: Colors.white.withOpacity(0.85),
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
                            icon: Icons.groups_outlined,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricCard(
                            label: l10n.subjectsLabel,
                            value: subjectCount.toString(),
                            icon: Icons.menu_book_outlined,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricCard(
                            label: l10n.teachers,
                            value: teacherCount.toString(),
                            icon: Icons.school_outlined,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.subjectsAndTeachers,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (provider.classSubjects.isEmpty)
                    SizedBox(
                      height: 220,
                      child: EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: l10n.noSubjectsInClass,
                        message: l10n.addSubjectToStart,
                      ),
                    )
                  else
                    ...provider.classSubjects.asMap().entries.map((entry) {
                      final assignment = entry.value;
                      final color =
                          _kSubjectPalette[entry.key % _kSubjectPalette.length];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.lgRadius,
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppShadows.card,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.lgRadius,
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppGradients.tint(color),
                              borderRadius: AppRadius.mdRadius,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.menu_book_outlined,
                              color: color,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            assignment.subject ?? '',
                            style: theme.textTheme.titleMedium,
                          ),
                          subtitle: Row(
                            children: [
                              CircleAvatar(
                                radius: 9,
                                backgroundColor: color.withOpacity(0.15),
                                child: Text(
                                  assignment.teacherName.isEmpty
                                      ? '?'
                                      : assignment.teacherName[0]
                                            .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  assignment.teacherName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            tooltip: l10n.removeAssignment,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.danger,
                            ),
                            onPressed: () => _confirmRemove(
                              assignment.teacherId,
                              assignment.id,
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openAddSubjectDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.addSubjectTitle),
                  ),
                ],
              ),
      ),
    );
  }
}
