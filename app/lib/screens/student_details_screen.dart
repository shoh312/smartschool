import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/student.dart';
import '../providers/journal_provider.dart';
import '../routes/app_routes.dart';
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

    if (student != null && !_requested) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<JournalProvider>().loadForStudent(student.id);
      });
    }

    final journal = context.watch<JournalProvider>();

    return AppShell(
      title: student?.fullName ?? l10n.students,
      child: student == null
          ? Center(child: Text(l10n.studentNotFound))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.lgRadius,
                    border: Border.all(color: AppColors.border),
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
                  onPressed: () =>
                      Navigator.pushNamed(
                        context,
                        AppRoutes.attendanceHistory,
                        arguments: {'studentId': student.id},
                      ),
                  icon: const Icon(Icons.history),
                  label: Text(l10n.viewAttendanceHistoryButton),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      Navigator.pushNamed(
                        context,
                        AppRoutes.liveAttendance,
                        arguments: {'studentId': student.id},
                      ),
                  icon: const Icon(Icons.sensors),
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
                    icon: Icons.grade_outlined,
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
                            icon: Icons.edit_note_outlined,
                            color: AppColors.success,
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
                            icon: Icons.insights_outlined,
                            color: AppColors.warning,
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
                        color: AppColors.surface,
                        borderRadius: AppRadius.lgRadius,
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.card,
                      ),
                      child: ListTile(
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
    if (value >= 9) return AppColors.success;
    if (value >= 7) return AppColors.info;
    if (value >= 5) return AppColors.warning;
    return AppColors.danger;
  }
}
