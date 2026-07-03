import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../models/student.dart';
import '../providers/journal_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';

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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          child: Text(
                            student.firstName.isEmpty
                                ? '?'
                                : student.firstName[0],
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
                              const SizedBox(height: 4),
                              Text(l10n.classLabel(student.classId?.toString() ?? '-')),
                              Text(l10n.parentLabel(student.parentId?.toString() ?? '-')),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                  'Baholar',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (journal.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (journal.grades.isEmpty)
                  const EmptyState(
                    icon: Icons.grade_outlined,
                    title: 'Hali baho yo\'q',
                    message: 'O\'qituvchi baho qo\'yganda bu yerda ko\'rinadi.',
                  )
                else
                  ...journal.grades.map(
                    (grade) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _gradeColor(grade.value).withOpacity(0.15),
                          child: Text(
                            grade.value.toString(),
                            style: TextStyle(
                              color: _gradeColor(grade.value),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(grade.subject),
                        subtitle: Text(
                          grade.comment?.isNotEmpty == true
                              ? grade.comment!
                              : '${grade.gradeDate.year}-${grade.gradeDate.month.toString().padLeft(2, '0')}-${grade.gradeDate.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Uy vazifasi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (journal.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (journal.homework.isEmpty)
                  const EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'Hali uy vazifasi yo\'q',
                    message: 'O\'qituvchi uy vazifasi berganda bu yerda ko\'rinadi.',
                  )
                else
                  ...journal.homework.map(
                    (hw) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.assignment_outlined),
                        title: Text(hw.subject),
                        subtitle: Text(hw.description),
                        trailing: hw.dueDate == null
                            ? null
                            : Text(
                                '${hw.dueDate!.month.toString().padLeft(2, '0')}-${hw.dueDate!.day.toString().padLeft(2, '0')}',
                              ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Color _gradeColor(int value) {
    if (value >= 5) return const Color(0xFF22C55E);
    if (value == 4) return const Color(0xFF3B82F6);
    if (value == 3) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}
