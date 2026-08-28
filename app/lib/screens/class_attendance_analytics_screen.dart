import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';
import '../core/design_tokens.dart';
import '../models/analytics.dart';
import '../models/school_class.dart';

import '../services/analytics_service.dart';
import '../services/api_client.dart';
import '../utils/attendance_pdf_report.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/analytics/subject_radar_chart.dart';
import '../widgets/app_loading_indicator.dart';
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
    this.todayStatus,
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

  /// Today's verdict: 'present', 'late', 'absent', 'left_school', or null
  /// while the cameras have not decided yet. Drives the card's border, so a
  /// director reads the room today rather than only the month's average.
  final String? todayStatus;

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
      todayStatus: json['today_status'] as String?,
    );
  }
}

/// How a student's day is going, and what it should look like.
///
/// Kept as a type rather than a bare string so the colour, label and icon
/// for "late" are decided once instead of at each place that draws it.
enum TodayStanding { present, late, absent, pending }

TodayStanding todayStandingFrom(String? status) {
  switch (status) {
    case 'present':
      return TodayStanding.present;
    case 'late':
      return TodayStanding.late;
    case 'absent':
    case 'left_school':
      return TodayStanding.absent;
    default:
      // No record yet: the cameras have not finished their second pass, so
      // nothing has been decided. Deliberately not "absent" -- saying a
      // child is missing before anyone has looked twice is how a parent
      // gets a false alarm.
      return TodayStanding.pending;
  }
}

extension TodayStandingStyle on TodayStanding {
  Color color(BuildContext context) => switch (this) {
        TodayStanding.present => context.colors.success,
        TodayStanding.late => context.colors.warning,
        TodayStanding.absent => context.colors.danger,
        TodayStanding.pending => context.colors.textMuted,
      };

  IconData get icon => switch (this) {
        TodayStanding.present => Icons.check_circle_rounded,
        TodayStanding.late => Icons.schedule_rounded,
        TodayStanding.absent => Icons.cancel_rounded,
        TodayStanding.pending => Icons.hourglass_empty_rounded,
      };

  String label(AppLocalizations l10n) => switch (this) {
        TodayStanding.present => l10n.present,
        TodayStanding.late => l10n.late,
        TodayStanding.absent => l10n.absent,
        TodayStanding.pending => l10n.awaitingDetection,
      };

  /// Only a decided status earns a coloured edge. Leaving "pending" on the
  /// ordinary hairline keeps the screen calm: the eye should be drawn to
  /// the students something is known about, not to everyone at once.
  bool get highlights => this != TodayStanding.pending;
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

  /// Per-subject standing for this class. Empty until loaded, and left empty
  /// on failure: it's an extra block on an attendance screen, so it must
  /// never be the reason the page shows an error.
  List<ClassSubjectAverage> _subjects = const [];

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
    await _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await context
          .read<AnalyticsService>()
          .classSubjects(classId: widget.schoolClass.id);
      if (mounted) setState(() => _subjects = subjects);
    } catch (_) {
      if (mounted) setState(() => _subjects = const []);
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
          ? const AppLoadingIndicator()
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.noDataTitle,
                  message: l10n.errorPrefix(_error!),
                  onAction: _load,
                  actionLabel: l10n.retry,
                )
              : _analytics == null || _analytics!.isEmpty
                  ? EmptyState(
                      icon: Icons.analytics_outlined,
                      title: l10n.noDataTitle,
                      message: l10n.noAttendanceDataLast30Days,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
                        children: [
                          // Laid out by hand rather than with a shrink-wrapped
                          // GridView: that reserved noticeably more height
                          // than its two rows of cards actually used, leaving
                          // a dead band above the per-student list. Four fixed
                          // cards don't need a grid's machinery anyway.
                          _MetricRow(
                            children: [
                              MetricCard(
                                label: l10n.students,
                                value: _analytics!.length.toString(),
                                icon: Icons.groups_2_outlined,
                              ),
                              MetricCard(
                                label: l10n.present,
                                value: _countByLatestStatus((s) => s == 'present').toString(),
                                icon: Icons.check_circle_outline,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _MetricRow(
                            children: [
                              MetricCard(
                                label: l10n.late,
                                value: _countByLatestStatus((s) => s == 'late').toString(),
                                icon: Icons.schedule_rounded,
                              ),
                              MetricCard(
                                label: l10n.absent,
                                value: _countByLatestStatus((s) => s == 'absent' || s == 'left_school').toString(),
                                icon: Icons.cancel_outlined,
                              ),
                            ],
                          ),
                          if (_subjects.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            DashboardSectionHeader(title: l10n.subjectStrengths),
                            _SubjectStrengthCard(subjects: _subjects),
                          ],
                          const SizedBox(height: 20),
                          DashboardSectionHeader(title: l10n.perStudentDetails),
                          ..._analytics!.asMap().entries.map((mapEntry) {
                            final index = mapEntry.key;
                            final summary = mapEntry.value;
                            return FadeSlideIn(
                              delay: index < 12
                                  ? Duration(milliseconds: 40 * index)
                                  : Duration.zero,
                              child: _StudentCard(
                                summary: summary,
                                rateColor: _rateColor(summary.attendanceRate),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }
}

/// Which subjects this class is strong and weak in, as one bar per subject.
///
/// Bars are drawn against a fixed 0-10 scale rather than against the best
/// subject in the class: stretched to the local maximum, a class averaging
/// 4 everywhere would still show one full-length bar and read as a success.
class _SubjectStrengthCard extends StatelessWidget {
  const _SubjectStrengthCard({required this.subjects});

  /// Already sorted strongest-first by the server.
  final List<ClassSubjectAverage> subjects;

  static const _maxGrade = 10.0;

  Color _color(BuildContext context, double average) {
    if (average >= 8) return context.colors.success;
    if (average >= 6) return context.colors.warning;
    return context.colors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final best = subjects.first;
    final worst = subjects.length > 1 ? subjects.last : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The headline: a director shouldn't have to read every bar to
          // learn the two things they came for.
          Row(
            children: [
              Expanded(
                child: _SubjectVerdict(
                  label: l10n.strongestSubject,
                  subject: best.subject,
                  average: best.average,
                  color: context.colors.success,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              if (worst != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _SubjectVerdict(
                    label: l10n.weakestSubject,
                    subject: worst.subject,
                    average: worst.average,
                    color: context.colors.danger,
                    icon: Icons.trending_down_rounded,
                  ),
                ),
              ],
            ],
          ),
          // The shape first, the numbers under it: the chart answers "where
          // is this class caving in" in one look, the rows answer "by how
          // much, and over how many pupils".
          if (subjects.length >= SubjectRadarChart.minSubjects) ...[
            const SizedBox(height: 6),
            SubjectRadarChart(subjects: subjects),
            Divider(color: context.colors.border, height: 1),
          ],
          const SizedBox(height: 4),
          for (final subject in subjects)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.subjectCoverage(subject.studentCount, subject.gradeCount),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        subject.average.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _color(context, subject.average),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: subject.average / _maxGrade),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: context.colors.surfaceSunken,
                        valueColor: AlwaysStoppedAnimation(
                          _color(context, subject.average),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubjectVerdict extends StatelessWidget {
  const _SubjectVerdict({
    required this.label,
    required this.subject,
    required this.average,
    required this.color,
    required this.icon,
  });

  final String label;
  final String subject;
  final double average;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          Text(
            average.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of equal-width metric cards, each as tall as the tallest of them.
///
/// [IntrinsicHeight] is what keeps the pair matched without hard-coding a
/// height: a card is only as tall as its own text needs, so a fixed number
/// would either clip a long label or leave the very padding this replaced.
class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// One student's row on the class analytics screen.
///
/// Two different things are on this card and they answer different
/// questions. The border and the badge say how *today* is going, which is
/// what a director opens the screen for during a school day. Everything
/// inside is the month behind it, which is what they open it for when
/// deciding who needs a conversation.
class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.summary, required this.rateColor});

  final StudentAttendanceSummary summary;
  final Color rateColor;

  String get _initials {
    final first = summary.firstName.isNotEmpty ? summary.firstName[0] : '';
    final last = summary.lastName.isNotEmpty ? summary.lastName[0] : '';
    final result = ('$first$last').toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final standing = todayStandingFrom(summary.todayStatus);
    final accent = standing.color(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        // A decided status gets a full coloured edge; an undecided one keeps
        // the app's ordinary hairline so it recedes.
        border: Border.all(
          color: standing.highlights ? accent.withOpacity(0.55) : context.colors.border,
          width: standing.highlights ? 1.6 : 1,
        ),
        // No shadow. A coloured glow behind every card turned a list of
        // thirty students into thirty halos competing for attention -- the
        // border already carries the status, and it reads better against a
        // flat surface than against a smear of the same colour.
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A tinted strip behind the name, so the status reads even at a
          // glance down a long list of cards.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: standing.highlights
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [accent.withOpacity(0.14), accent.withOpacity(0.02)],
                    )
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: AppRadius.mdRadius,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${summary.firstName} ${summary.lastName}',
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(standing.icon, size: 13, color: accent),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              standing.label(l10n),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: rateColor.withOpacity(0.12),
                    borderRadius: AppRadius.smRadius,
                    border: Border.all(color: rateColor.withOpacity(0.22)),
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
          ),
          Divider(height: 1, color: context.colors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Stat(
                      label: l10n.present,
                      value: '${summary.presentDays}d',
                      color: context.colors.success,
                    ),
                    const SizedBox(width: 16),
                    _Stat(
                      label: l10n.late,
                      value: '${summary.lateDays}d',
                      color: context.colors.warning,
                    ),
                    const SizedBox(width: 16),
                    _Stat(
                      label: l10n.absent,
                      value: '${summary.absentDays}d',
                      color: context.colors.danger,
                    ),
                    const Spacer(),
                    _Stat(
                      label: l10n.hoursLabel,
                      value: '${summary.totalPresentHours.toStringAsFixed(1)}h',
                      color: context.colors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DailyTimeline(records: summary.dailyRecords),
              ],
            ),
          ),
        ],
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
