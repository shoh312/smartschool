import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../utils/date_formatters.dart';
import '../widgets/attendance/attendance_streak.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/empty_state.dart';
import '../widgets/grade_detail_sheet.dart';
import '../widgets/metric_card.dart';
import '../widgets/status_chip.dart';

const double _kCellSpacing = 4;

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

Color _statusColor(BuildContext context, AttendanceStatus status) => switch (status) {
  AttendanceStatus.present => context.colors.success,
  AttendanceStatus.absent => context.colors.danger,
  AttendanceStatus.late => context.colors.warning,
  AttendanceStatus.leftSchool => context.colors.primary,
  AttendanceStatus.notDetected => context.colors.textMuted,
};

/// Read-only monthly attendance calendar for a single student -- the
/// attendance counterpart to StudentJournalScreen's grade grid. A real
/// calendar (weeks of 7) fits attendance better than that grid layout since
/// there's exactly one record per day, not one per subject per day.
class StudentAttendanceJournalScreen extends StatefulWidget {
  const StudentAttendanceJournalScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.parentId,
    this.viaPublicServer = false,
  });

  final int studentId;
  final String studentName;
  final bool viaPublicServer;
  final int? parentId;

  @override
  State<StudentAttendanceJournalScreen> createState() =>
      _StudentAttendanceJournalScreenState();
}

class _StudentAttendanceJournalScreenState
    extends State<StudentAttendanceJournalScreen> {
  late DateTime _viewedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewedMonth = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadHistory(
        studentId: widget.studentId,
        parentId: widget.parentId,
        viaPublicServer: widget.viaPublicServer,
      );
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _viewedMonth.year == now.year && _viewedMonth.month == now.month;
  }

  void _changeMonth(int delta) {
    setState(() {
      _viewedMonth = DateTime(_viewedMonth.year, _viewedMonth.month + delta);
    });
  }

  void _showDayDetails(AttendanceRecord record) {
    showDetailBottomSheet(
      context,
      contentBuilder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormatters.shortDate(record.attendanceDate),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                AttendanceStatusChip(status: record.status),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              l10n.inTimeOutTime(
                DateFormatters.time(record.timeIn),
                DateFormatters.time(record.timeOut),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (record.lastSeen != null) ...[
              const SizedBox(height: 12),
              Text(l10n.lastSeenLabel, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(DateFormatters.time(record.lastSeen), style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AttendanceProvider>();
    final theme = Theme.of(context);
    final today = _dateOnly(DateTime.now());
    final monthLabel = DateFormatters.monthYear(l10n, _viewedMonth);

    final recordsByDate = <String, AttendanceRecord>{};
    for (final record in provider.history) {
      recordsByDate[_dateKey(_dateOnly(record.attendanceDate))] = record;
    }

    final monthRecords = provider.history.where((record) {
      final date = _dateOnly(record.attendanceDate);
      return date.year == _viewedMonth.year && date.month == _viewedMonth.month;
    }).toList();
    final presentCount = monthRecords
        .where((r) => r.status == AttendanceStatus.present)
        .length;
    final lateCount = monthRecords
        .where((r) => r.status == AttendanceStatus.late)
        .length;
    final absentCount = monthRecords
        .where((r) => r.status == AttendanceStatus.absent)
        .length;

    final streak = computeAttendanceStreak(provider.history);

    final firstOfMonth = DateTime(_viewedMonth.year, _viewedMonth.month, 1);
    final daysInMonth = DateTime(_viewedMonth.year, _viewedMonth.month + 1, 0).day;
    final leadingEmpty = firstOfMonth.weekday - 1;
    final totalCells = leadingEmpty + daysInMonth;
    final trailingEmpty = (7 - totalCells % 7) % 7;
    final cells = <DateTime?>[
      ...List.filled(leadingEmpty, null),
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(_viewedMonth.year, _viewedMonth.month, day),
      ...List.filled(trailingEmpty, null),
    ];
    final weeks = <List<DateTime?>>[
      for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7),
    ];

    return AppShell(
      title: widget.studentName,
      child: RefreshIndicator(
        onRefresh: () => context.read<AttendanceProvider>().loadHistory(
          studentId: widget.studentId,
          parentId: widget.parentId,
          viaPublicServer: widget.viaPublicServer,
        ),
        child: provider.isLoading && provider.history.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
                children: [
                  // "How am I doing" before "which day was it": the counts
                  // below answer a question you only ask once you have a
                  // reason to look.
                  if (!streak.isEmpty) ...[
                    AttendanceStreakCard(streak: streak),
                    const SizedBox(height: 12),
                  ],
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: MetricCard(
                            label: l10n.present,
                            value: presentCount.toString(),
                            icon: Icons.check_circle_outline,
                            color: context.colors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricCard(
                            label: l10n.late,
                            value: lateCount.toString(),
                            icon: Icons.schedule_rounded,
                            color: context.colors.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricCard(
                            label: l10n.absent,
                            value: absentCount.toString(),
                            icon: Icons.cancel_outlined,
                            color: context.colors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: AppRadius.lgRadius,
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () => _changeMonth(-1),
                        ),
                        Expanded(
                          child: Text(
                            monthLabel,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (monthRecords.isEmpty)
                    EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: l10n.noAttendanceRecords,
                      message: l10n.noAttendanceThisMonth,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: AppRadius.lgRadius,
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              for (var weekday = 1; weekday <= 7; weekday++)
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      DateFormatters.weekdayShort(l10n, weekday),
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: context.colors.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (final week in weeks) ...[
                            Row(
                              children: [
                                for (final date in week)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(_kCellSpacing / 2),
                                      child: _DayCell(
                                        date: date,
                                        isToday: date != null && date == today,
                                        record: date == null
                                            ? null
                                            : recordsByDate[_dateKey(date)],
                                        onTap: _showDayDetails,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isToday,
    required this.record,
    required this.onTap,
  });

  final DateTime? date;
  final bool isToday;
  final AttendanceRecord? record;
  final ValueChanged<AttendanceRecord> onTap;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return const SizedBox(height: 44);
    }

    final record = this.record;
    final color = record == null ? null : _statusColor(context, record.status);

    final cell = Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color?.withOpacity(0.12) ?? context.colors.surfaceAlt,
        borderRadius: AppRadius.smRadius,
        border: Border.all(
          color: isToday ? context.colors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Text(
        '${date!.day}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: isToday || record != null ? FontWeight.w700 : FontWeight.w500,
          color: color ?? context.colors.textMuted,
        ),
      ),
    );

    if (record == null) return cell;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.smRadius,
        onTap: () => onTap(record),
        child: cell,
      ),
    );
  }
}
