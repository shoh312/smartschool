import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/app_role.dart';
import '../models/grade.dart';
import '../models/student.dart';
import '../providers/auth_provider.dart';
import '../providers/journal_provider.dart';
import '../screens/class_live_attendance_screen.dart';
import '../screens/student_attendance_journal_screen.dart';
import '../screens/student_journal_screen.dart';
import '../utils/date_formatters.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_card.dart';

class StudentDetailsScreen extends StatefulWidget {
  const StudentDetailsScreen({super.key});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    final student = ModalRoute.of(context)!.settings.arguments as Student?;
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    final parentId = auth.role == AppRole.parent ? auth.parentId : null;

    if (student != null && !_requested) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<JournalProvider>().loadForStudent(
          student.id,
          parentId: parentId,
        );
      });
    }

    final journal = context.watch<JournalProvider>();

    return AppShell(
      title: student?.fullName ?? l10n.students,
      actions: student == null
          ? const []
          : [
              IconButton(
                tooltip: l10n.viewJournal,
                icon: const Icon(Icons.menu_book_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentJournalScreen(
                      studentId: student.id,
                      studentName: student.fullName,
                      parentId: parentId,
                    ),
                  ),
                ),
              ),
            ],
      child: student == null
          ? Center(child: Text(l10n.studentNotFound))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: AppRadius.lgRadius,
                    border: Border.all(color: context.colors.border),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          gradient: AppGradients.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          student.firstName.isEmpty
                              ? '?'
                              : student.firstName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.fullName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.classLabel(student.className ?? '-'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              l10n.parentLabel(
                                student.parentName ??
                                    student.parentPhone ??
                                    '-',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentAttendanceJournalScreen(
                        studentId: student.id,
                        studentName: student.fullName,
                        parentId: parentId,
                      ),
                    ),
                  ),
                  icon: Image.asset('assets/icons/history.png', width: 20, height: 20),
                  label: Text(l10n.viewAttendanceHistoryButton),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: student.classId == null
                      ? () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.studentNotAssignedToClass)),
                          )
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClassLiveAttendanceScreen(
                                classId: student.classId!,
                                className: student.className ?? '-',
                              ),
                            ),
                          ),
                  icon: Image.asset('assets/icons/live_stream.png', width: 20, height: 20),
                  label: Text(l10n.viewLiveStatusButton),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.grades,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (journal.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (journal.grades.isEmpty)
                  EmptyState(
                    imageAsset: 'assets/icons/grades.png',
                    title: l10n.noGrades,
                    message: l10n.noGradesMessage,
                  )
                else ...[
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: MetricCard(
                            label: l10n.grades,
                            value: journal.grades.length.toString(),
                            imageAsset: 'assets/icons/grades.png',
                            color: context.colors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricCard(
                            label: l10n.average,
                            value:
                                (journal.grades
                                            .map((g) => g.value)
                                            .reduce((a, b) => a + b) /
                                        journal.grades.length)
                                    .toStringAsFixed(1),
                            imageAsset: 'assets/icons/average.png',
                            color: context.colors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...journal.grades.map(
                    (grade) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: AppRadius.lgRadius,
                        border: Border.all(color: context.colors.border),
                        boxShadow: AppShadows.card,
                      ),
                      child: ListTile(
                        onTap: () => _showGradeDetails(context, grade),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _gradeColor(grade.value),
                            borderRadius: AppRadius.smRadius,
                            boxShadow: AppShadows.colored(_gradeColor(grade.value)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            grade.value.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          grade.subject,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          grade.comment?.isNotEmpty == true
                              ? '${grade.comment!} • ${DateFormatters.shortDate(grade.gradeDate)}'
                              : DateFormatters.shortDate(grade.gradeDate),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Color _gradeColor(int value) {
    if (value >= 9) return context.colors.success;
    if (value >= 7) return context.colors.info;
    if (value >= 5) return context.colors.warning;
    return context.colors.danger;
  }

  void _showGradeDetails(BuildContext context, Grade grade) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.colors.borderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _gradeColor(grade.value).withOpacity(0.15),
                      borderRadius: AppRadius.mdRadius,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      grade.value.toString(),
                      style: TextStyle(
                        color: _gradeColor(grade.value),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grade.subject,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          DateFormatters.shortDate(grade.gradeDate),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                l10n.journalTeacherLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                grade.teacherName ?? '-',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.journalCommentOptional,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                (grade.comment == null || grade.comment!.isEmpty)
                    ? l10n.journalNoComment
                    : grade.comment!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdRadius,
                  ),
                ),
                child: Text(l10n.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
