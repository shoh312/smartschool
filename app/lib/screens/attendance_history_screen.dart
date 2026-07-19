import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/date_formatters.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_chip.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final studentId = args?['studentId'] as int?;
      final parentId = context.read<AuthProvider>().parentId;
      context.read<AttendanceProvider>().loadHistory(
        parentId: studentId == null ? parentId : null,
        studentId: studentId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.attendanceHistory,
      child: provider.isLoading && provider.history.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.history.isEmpty
          ? EmptyState(
              icon: Icons.history,
              title: l10n.noAttendanceRecords,
              message: l10n.recordsWillAppear,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = provider.history[index];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.lgRadius,
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.card,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppGradients.tint(AppColors.primary),
                        borderRadius: AppRadius.mdRadius,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.event_available_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      DateFormatters.shortDate(record.attendanceDate),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      l10n.inTimeOutTime(
                        DateFormatters.time(record.timeIn),
                        DateFormatters.time(record.timeOut),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: AttendanceStatusChip(status: record.status),
                  ),
                );
              },
            ),
    );
  }
}
