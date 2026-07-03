import 'package:flutter/material.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../models/student.dart';
import '../routes/app_routes.dart';
import '../widgets/app_shell.dart';

class StudentDetailsScreen extends StatelessWidget {
  const StudentDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final student = ModalRoute.of(context)!.settings.arguments as Student?;
    final l10n = AppLocalizations.of(context)!;

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
              ],
            ),
    );
  }
}

