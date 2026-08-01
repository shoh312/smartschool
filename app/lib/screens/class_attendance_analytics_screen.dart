import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';
import '../core/design_tokens.dart';
import '../models/school_class.dart';

import '../services/api_client.dart';
import '../utils/attendance_pdf_report.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_card.dart';

class DailyRecord {
  final String date;
  final String status;
  const DailyRecord({required this.date, required this.status});
  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    return DailyRecord(
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

class StudentAttendanceSummary {
  const StudentAttendanceSummary({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.totalPresentHours,
    required this.totalAbsentHours,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.attendanceRate,
    this.dailyRecords = const [],
  });

  final int studentId;
  final String firstName;
  final String lastName;
  final double totalPresentHours;
  final double totalAbsentHours;
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final double attendanceRate;
  final List<DailyRecord> dailyRecords;

  factory StudentAttendanceSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['daily_records'] as List<dynamic>?;
    return StudentAttendanceSummary(
      studentId: json['student_id'] as int,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      totalPresentHours: (json['total_present_hours'] as num?)?.toDouble() ?? 0,
      totalAbsentHours: (json['total_absent_hours'] as num?)?.toDouble() ?? 0,
      totalDays: json['total_days'] as int? ?? 0,
      presentDays: json['present_days'] as int? ?? 0,
      absentDays: json['absent_days'] as int? ?? 0,
      lateDays: json['late_days'] as int? ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0,
      dailyRecords: raw == null ? [] : raw.map((e) => DailyRecord.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ClassAttendanceAnalyticsScreen extends StatefulWidget {
  const ClassAttendanceAnalyticsScreen({
    super.key,
    required this.schoolClass,
  });

  final SchoolClass schoolClass;

  @override
  State<ClassAttendanceAnalyticsScreen> createState() =>
      _ClassAttendanceAnalyticsScreenState();
}

class _ClassAttendanceAnalyticsScreenState
    extends State<ClassAttendanceAnalyticsScreen> {
  List<StudentAttendanceSummary>? _analytics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiClient>();
      final data = await api.get('/attendance/class-analytics/${widget.schoolClass.id}?days=30') as List<dynamic>;
      _analytics = data
          .map((item) => StudentAttendanceSummary.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Color _rateColor(double rate) {
    if (rate >= 80) return context.colors.success;
    if (rate >= 60) return context.colors.warning;
    return context.colors.danger;
  }

  int _countByLatestStatus(bool Function(String status) matches) {
    return _analytics!.where((s) {
      if (s.dailyRecords.isEmpty) return false;
      return matches(s.dailyRecords.last.status);
    }).length;
  }

  Future<void> _pickMonthAndDownloadReport() async {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    var selectedMonth = now.month;
    var selectedYear = now.year;
    final years = [for (var y = now.year - 2; y <= now.year; y++) y];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.selectMonth),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedMonth,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text(monthLabel(l10n, m))),
                  ],
                  onChanged: (v) => setDialogState(() => selectedMonth = v ?? selectedMonth),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedYear,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final y in years) DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedYear = v ?? selectedYear),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.generatePdfReport),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.generatePdfReport)),
    );

    try {
      await generateClassMonthlyReportPdf(
        context: context,
        classId: widget.schoolClass.id,
        className: widget.schoolClass.name,
        year: selectedYear,
        month: selectedMonth,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorPrefix(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.analyticsScreenTitle(widget.schoolClass.name),
      showAppBar: !(context.findAncestorStateOfType<ScaffoldState>() != null),
      actions: [
        IconButton(
          tooltip: l10n.generatePdfReport,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: _pickMonthAndDownloadReport,
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(l10n.errorPrefix(_error!)))
              : _analytics == null || _analytics!.isEmpty
                  ? EmptyState(
                      icon: Icons.analytics_outlined,
                      title: l10n.noDataTitle,
                      message: l10n.noAttendanceDataLast30Days,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth > 600 ? 4 : 2;
                              return GridView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 100,
                                ),
                                children: [
                                  MetricCard(
                                    label: l10n.students,
                                    value: _analytics!.length.toString(),
                                    imageAsset: 'assets/icons/students.png',
                                  ),
                                  MetricCard(
                                    label: l10n.present,
                                    value: _countByLatestStatus((s) => s == 'present').toString(),
                                    imageAsset: 'assets/icons/present.png',
                                  ),
                                  MetricCard(
                                    label: l10n.late,
                                    value: _countByLatestStatus((s) => s == 'late').toString(),
                                    imageAsset: 'assets/icons/late.png',
                                  ),
                                  MetricCard(
                                    label: l10n.absent,
                                    value: _countByLatestStatus((s) => s == 'absent' || s == 'left_school').toString(),
                                    imageAsset: 'assets/icons/absent.png',
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.perStudentDetails,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          ..._analytics!.map((summary) {
                            final rateColor = _rateColor(summary.attendanceRate);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius: AppRadius.lgRadius,
                                border: Border.all(color: context.colors.border),
                                boxShadow: AppShadows.card,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            gradient: AppGradients.primary,
                                            borderRadius: AppRadius.mdRadius,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${summary.firstName[0]}${summary.lastName[0]}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            '${summary.firstName} ${summary.lastName}',
                                            style: theme.textTheme.titleSmall,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: rateColor.withOpacity(0.12),
                                            borderRadius: AppRadius.smRadius,
                                            border: Border.all(color: rateColor.withOpacity(0.18)),
                                          ),
                                          child: Text(
                                            '${summary.attendanceRate.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              color: rateColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _Stat(label: l10n.present, value: '${summary.presentDays}d', color: context.colors.success),
                                        const SizedBox(width: 16),
                                        _Stat(label: l10n.late, value: '${summary.lateDays}d', color: context.colors.warning),
                                        const SizedBox(width: 16),
                                        _Stat(label: l10n.absent, value: '${summary.absentDays}d', color: context.colors.danger),
                                        const Spacer(),
                                        _Stat(
                                          label: l10n.hoursLabel,
                                          value: '${summary.totalPresentHours.toStringAsFixed(1)}h',
                                          color: context.colors.primary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    _DailyTimeline(records: summary.dailyRecords),
                                  ],
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

class _DailyTimeline extends StatelessWidget {
  const _DailyTimeline({required this.records});

  final List<DailyRecord> records;

  Color _color(BuildContext context, String status) {
    switch (status) {
      case 'present':
        return context.colors.success;
      case 'late':
        return context.colors.warning;
      case 'absent':
      case 'left_school':
        return context.colors.danger;
      default:
        return context.colors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.thirtyDayTimeline,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 2,
          runSpacing: 2,
          children: records.map((r) {
            return Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _color(context, r.status),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _DotLegend(color: context.colors.success, label: l10n.present),
            const SizedBox(width: 12),
            _DotLegend(color: context.colors.warning, label: l10n.late),
            const SizedBox(width: 12),
            _DotLegend(color: context.colors.danger, label: l10n.absent),
            const SizedBox(width: 12),
            _DotLegend(color: context.colors.border, label: l10n.noDataTitle),
          ],
        ),
      ],
    );
  }
}

class _DotLegend extends StatelessWidget {
  const _DotLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
