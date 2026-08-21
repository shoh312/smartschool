import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/student_provider.dart';
import '../utils/date_formatters.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_card.dart';
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
      // Needed to put a name and class on each row: the attendance records
      // themselves carry only a student id, so a school-wide history would
      // otherwise be an unreadable run of identical dates.
      context.read<StudentProvider>().loadStudents(parentId: parentId);
    });
  }

  /// Newest first, then split into month blocks. A flat run of dates gives
  /// the eye nothing to hold on to; month headers turn it into something you
  /// can scan and scroll by.
  List<Object> _buildRows(List<AttendanceRecord> history) {
    final sorted = List.of(history)
      ..sort((a, b) => b.attendanceDate.compareTo(a.attendanceDate));

    final rows = <Object>[];
    DateTime? currentMonth;
    for (final record in sorted) {
      final month = DateTime(record.attendanceDate.year, record.attendanceDate.month);
      if (currentMonth == null || month != currentMonth) {
        currentMonth = month;
        rows.add(month);
      }
      rows.add(record);
    }
    return rows;
  }

  /// Level one of the drill-down: one row per class, carrying how many of
  /// its records were absences so the worst class is visible without
  /// opening anything.
  List<Widget> _buildClassRows(
    BuildContext context,
    List<AttendanceRecord> history,
    Map<int, Student> students,
    AppLocalizations l10n,
  ) {
    final byClass = <String, List<AttendanceRecord>>{};
    for (final record in history) {
      final className = students[record.studentId]?.className ?? '—';
      byClass.putIfAbsent(className, () => []).add(record);
    }
    final classNames = byClass.keys.toList()..sort();

    return [
      DashboardSectionHeader(title: l10n.classes),
      for (var i = 0; i < classNames.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FadeSlideIn(
            delay: i < 12 ? Duration(milliseconds: 40 * i) : Duration.zero,
            child: _GroupRow(
              badgeText: classNames[i],
              title: classNames[i],
              subtitle:
                  '${byClass[classNames[i]]!.map((r) => r.studentId).toSet().length} ${l10n.students}',
              absentCount: byClass[classNames[i]]!
                  .where((r) => r.status == AttendanceStatus.absent)
                  .length,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _ClassHistoryScreen(
                    className: classNames[i],
                    records: byClass[classNames[i]]!,
                    students: students,
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final l10n = AppLocalizations.of(context)!;

    int count(AttendanceStatus status) =>
        provider.history.where((r) => r.status == status).length;
    final rows = _buildRows(provider.history);

    // A director's history spans the whole school, so each row has to say
    // which pupil it belongs to; a parent looking at one child does not need
    // the name repeated on every line.
    final students = {
      for (final student in context.watch<StudentProvider>().students)
        student.id: student,
    };
    final showsManyStudents =
        provider.history.map((r) => r.studentId).toSet().length > 1;

    return AppShell(
      title: l10n.attendanceHistory,
      child: provider.isLoading && provider.history.isEmpty
          ? const AppLoadingIndicator()
          : provider.history.isEmpty
          ? EmptyState(
              icon: Icons.history_rounded,
              title: l10n.noAttendanceRecords,
              message: l10n.recordsWillAppear,
            )
          : ListView(
              padding: (const EdgeInsets.fromLTRB(16, 8, 16, 16)).add(bottomNavPadding(context)),
              children: [
                // What the whole period adds up to, before the day-by-day
                // detail -- the old screen opened straight into rows and
                // never answered "how has attendance been overall?".
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: l10n.present,
                          value: count(AttendanceStatus.present).toString(),
                          icon: Icons.check_circle_outline,
                          color: context.colors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricCard(
                          label: l10n.late,
                          value: count(AttendanceStatus.late).toString(),
                          icon: Icons.schedule_rounded,
                          color: context.colors.warning,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricCard(
                          label: l10n.absent,
                          value: count(AttendanceStatus.absent).toString(),
                          icon: Icons.cancel_outlined,
                          color: context.colors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                // School-wide, the raw records are drilled into rather than
                // dumped: classes, then that class's pupils, then one
                // pupil's days. A flat 100-row list of identical dates told
                // a director nothing about who or where.
                if (showsManyStudents)
                  ..._buildClassRows(context, provider.history, students, l10n)
                else
                  for (var i = 0; i < rows.length; i++)
                    if (rows[i] is DateTime)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                        child: DashboardSectionHeader(
                          title: DateFormatters.monthYear(l10n, rows[i] as DateTime),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FadeSlideIn(
                          delay: i < 14 ? Duration(milliseconds: 30 * i) : Duration.zero,
                          child: _HistoryRow(record: rows[i] as AttendanceRecord),
                        ),
                      ),
              ],
            ),
    );
  }
}

/// One day's attendance: the day number in a badge tinted by that day's
/// status, the weekday beside it, and the in/out times underneath. Colour
/// carries the outcome, so a month of rows can be judged by scanning the
/// left edge alone.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});

  final AttendanceRecord record;

  Color _statusColor(BuildContext context) => switch (record.status) {
        AttendanceStatus.present => context.colors.success,
        AttendanceStatus.late => context.colors.warning,
        AttendanceStatus.absent => context.colors.danger,
        _ => context.colors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final times = l10n.inTimeOutTime(
      DateFormatters.time(record.timeIn),
      DateFormatters.time(record.timeOut),
    );
    final weekday = DateFormatters.weekdayShort(l10n, record.attendanceDate.weekday);

    return AppListCard(
      leading: AppListBadge(
        text: '${record.attendanceDate.day}',
        color: _statusColor(context),
      ),
      title: weekday,
      subtitle: times,
      trailing: AttendanceStatusChip(status: record.status),
    );
  }
}

/// A drill-down row (a class, or a pupil) showing how many absences sit
/// inside it -- the number is what makes the list worth scanning.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.badgeText,
    required this.title,
    required this.subtitle,
    required this.absentCount,
    required this.onTap,
  });

  final String badgeText;
  final String title;
  final String subtitle;
  final int absentCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      leading: AppListBadge(text: badgeText),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (absentCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.colors.danger.withOpacity(0.12),
                borderRadius: AppRadius.smRadius,
              ),
              child: Text(
                '$absentCount',
                style: TextStyle(
                  color: context.colors.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 20, color: context.colors.textMuted),
        ],
      ),
    );
  }
}

/// Level two: the pupils of one class, each with their own absence count.
class _ClassHistoryScreen extends StatelessWidget {
  const _ClassHistoryScreen({
    required this.className,
    required this.records,
    required this.students,
  });

  final String className;
  final List<AttendanceRecord> records;
  final Map<int, Student> students;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final byStudent = <int, List<AttendanceRecord>>{};
    for (final record in records) {
      byStudent.putIfAbsent(record.studentId, () => []).add(record);
    }
    final studentIds = byStudent.keys.toList()
      ..sort((a, b) => (students[a]?.fullName ?? '').compareTo(students[b]?.fullName ?? ''));

    return AppShell(
      title: '${l10n.attendanceHistory} · $className',
      child: ListView(
        padding: (const EdgeInsets.fromLTRB(16, 8, 16, 16)).add(bottomNavPadding(context)),
        children: [
          DashboardSectionHeader(title: l10n.students),
          for (var i = 0; i < studentIds.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FadeSlideIn(
                delay: i < 12 ? Duration(milliseconds: 40 * i) : Duration.zero,
                child: _GroupRow(
                  badgeText: (students[studentIds[i]]?.firstName.isNotEmpty ?? false)
                      ? students[studentIds[i]]!.firstName[0].toUpperCase()
                      : '?',
                  title: students[studentIds[i]]?.fullName ?? '#${studentIds[i]}',
                  subtitle: '${byStudent[studentIds[i]]!.length} ${l10n.attendanceHistory}',
                  absentCount: byStudent[studentIds[i]]!
                      .where((r) => r.status == AttendanceStatus.absent)
                      .length,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _StudentHistoryScreen(
                        studentName: students[studentIds[i]]?.fullName ?? '#${studentIds[i]}',
                        records: byStudent[studentIds[i]]!,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Level three: one pupil's days, newest first, split by month.
class _StudentHistoryScreen extends StatelessWidget {
  const _StudentHistoryScreen({required this.studentName, required this.records});

  final String studentName;
  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = List.of(records)
      ..sort((a, b) => b.attendanceDate.compareTo(a.attendanceDate));

    final rows = <Object>[];
    DateTime? currentMonth;
    for (final record in sorted) {
      final month = DateTime(record.attendanceDate.year, record.attendanceDate.month);
      if (month != currentMonth) {
        currentMonth = month;
        rows.add(month);
      }
      rows.add(record);
    }

    return AppShell(
      title: studentName,
      child: ListView(
        padding: (const EdgeInsets.fromLTRB(16, 8, 16, 16)).add(bottomNavPadding(context)),
        children: [
          for (var i = 0; i < rows.length; i++)
            if (rows[i] is DateTime)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                child: DashboardSectionHeader(
                  title: DateFormatters.monthYear(l10n, rows[i] as DateTime),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FadeSlideIn(
                  delay: i < 14 ? Duration(milliseconds: 30 * i) : Duration.zero,
                  child: _HistoryRow(record: rows[i] as AttendanceRecord),
                ),
              ),
        ],
      ),
    );
  }
}
