import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/analytics.dart';
import '../models/grade.dart';
import '../services/analytics_service.dart';
import '../services/journal_service.dart';
import '../widgets/analytics/monthly_trend_chart.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';

/// A student's full quarterly rating: overall average, rank inside their
/// class/parallel/school, a per-subject breakdown (which subjects they're
/// strong/weak in), and lesson-attendance for the same quarter. Reachable
/// from a ranking leaderboard (director/teacher) or directly from a
/// parent's dashboard for their own child.
class StudentAnalyticsScreen extends StatefulWidget {
  const StudentAnalyticsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.parentId,
    this.viaPublicServer = false,
  });

  final int studentId;
  final String studentName;

  /// Set only when opened from the parent flow -- routes the request
  /// through the Public Server instead of the local school-network one.
  final int? parentId;

  /// Set for a student's own session (no parentId) -- same routing effect.
  final bool viaPublicServer;

  @override
  State<StudentAnalyticsScreen> createState() => _StudentAnalyticsScreenState();
}

class _StudentAnalyticsScreenState extends State<StudentAnalyticsScreen> {
  StudentAnalyticsOverview? _overview;
  bool _loading = true;
  String? _error;
  int? _quarter;

  /// The pupil's individual marks, for the day-by-day tab. The overview
  /// only carries per-quarter points, so the daily series is built here
  /// from the grades themselves rather than adding a second server trip's
  /// worth of schema to the analytics snapshot.
  List<Grade> _grades = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = context.read<AnalyticsService>();
      final overview = await service.studentOverview(
        studentId: widget.studentId,
        quarter: _quarter,
        parentId: widget.parentId,
        viaPublicServer: widget.viaPublicServer,
      );
      // Marks are a nice-to-have for the daily tab: a failure here must not
      // take the whole rating screen down with it.
      List<Grade> grades = const [];
      try {
        grades = await context.read<JournalService>().listGrades(
              studentId: widget.studentId,
              parentId: widget.parentId,
              viaPublicServer: widget.viaPublicServer,
            );
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _overview = overview;
        _quarter = overview.quarter;
        _grades = grades;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _scoreColor(BuildContext context, double value) {
    if (value >= 8) return context.colors.success;
    if (value >= 6) return context.colors.warning;
    return context.colors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final overview = _overview;

    return AppShell(
      // Falls back to the section name: a pupil looking at their own
      // rating has no name to be told, and passing an empty one left the
      // app bar as a blank strip above the content.
      title: widget.studentName.isEmpty ? l10n.ratingAnalytics : widget.studentName,
      child: _loading
          ? const AppLoadingIndicator()
          : _error != null
              ? Center(child: Text(l10n.errorPrefix(_error!)))
              : overview == null
                  ? EmptyState(
                      icon: Icons.insights_outlined,
                      title: l10n.noDataTitle,
                      message: l10n.noGradesYetMessage,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
                        children: [
                          FadeSlideIn(
                            child: _QuarterPicker(
                              selected: overview.quarter,
                              onChanged: (q) {
                                setState(() => _quarter = q);
                                _load();
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 80),
                            child: _OverallCard(overview: overview),
                          ),
                          if (overview.classAverage != null ||
                              overview.parallelAverage != null ||
                              overview.schoolAverage != null ||
                              _grades.isNotEmpty ||
                              overview.trend.where((p) => p.overallAverage != null).length > 1) ...[
                            const SizedBox(height: 16),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 130),
                              child: _ComparisonTrendCard(
                                overview: overview,
                                grades: _grades,
                              ),
                            ),
                          ],
                          if (overview.strongestSubject != null || overview.weakestSubject != null) ...[
                            const SizedBox(height: 16),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 160),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (overview.strongestSubject != null)
                                    Expanded(
                                      child: _HighlightCard(
                                        label: l10n.strongestSubject,
                                        subject: overview.strongestSubject!,
                                        color: context.colors.success,
                                        icon: Icons.trending_up_rounded,
                                      ),
                                    ),
                                  if (overview.strongestSubject != null && overview.weakestSubject != null)
                                    const SizedBox(width: 12),
                                  if (overview.weakestSubject != null)
                                    Expanded(
                                      child: _HighlightCard(
                                        label: l10n.weakestSubject,
                                        subject: overview.weakestSubject!,
                                        color: context.colors.danger,
                                        icon: Icons.trending_down_rounded,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          DashboardSectionHeader(title: l10n.subjectBreakdown),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 240),
                            child: overview.subjectBreakdown.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(24),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: context.colors.surface,
                                      borderRadius: AppRadius.lgRadius,
                                      border: Border.all(color: context.colors.border),
                                    ),
                                    child: Text(
                                      l10n.noGradesYetMessage,
                                      style: TextStyle(color: context.colors.textSecondary),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: context.colors.surface,
                                      borderRadius: AppRadius.lgRadius,
                                      border: Border.all(color: context.colors.border),
                                    ),
                                    child: Column(
                                      children: [
                                        for (final subject in overview.subjectBreakdown)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            child: _SubjectBar(
                                              subject: subject,
                                              color: _scoreColor(context, subject.average),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                          if (overview.lessonAttendanceRate != null) ...[
                            const SizedBox(height: 24),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 320),
                              child: _AttendanceRateCard(rate: overview.lessonAttendanceRate!),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

class _QuarterPicker extends StatelessWidget {
  const _QuarterPicker({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [l10n.quarter1, l10n.quarter2, l10n.quarter3, l10n.quarter4];

    return Row(
      children: [
        for (var q = 1; q <= 4; q++) ...[
          if (q > 1) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(q),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: q == selected ? AppGradients.primary : null,
                  color: q == selected ? null : context.colors.surface,
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(
                    color: q == selected ? Colors.transparent : context.colors.border,
                  ),
                ),
                child: Text(
                  labels[q - 1],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: q == selected ? Colors.white : context.colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.overview});

  final StudentAnalyticsOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final average = overview.overallAverage;
    final ribbon = achievementLabel(l10n, overview.classRank);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppShadows.colored(context.colors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.overallAverage,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              if (ribbon != null) AchievementRibbon(label: ribbon),
            ],
          ),
          const SizedBox(height: 4),
          average == null
              ? const Text(
                  '—',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 40, height: 1.1),
                )
              : AnimatedNumber(
                  value: average,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 40, height: 1.1),
                ),
          const SizedBox(height: 18),
          Row(
            children: [
              _RankBadge(label: l10n.classRank, rank: overview.classRank),
              const SizedBox(width: 10),
              _RankBadge(label: l10n.parallelRank, rank: overview.parallelRank),
              const SizedBox(width: 10),
              _RankBadge(label: l10n.schoolRank, rank: overview.schoolRank),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.label, required this.rank});

  final String label;
  final RankInfo rank;

  @override
  Widget build(BuildContext context) {
    final isTop = RankColors.isTopThree(rank.position);
    final medal = RankColors.forPosition(context, rank.position);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isTop ? medal.withOpacity(0.28) : Colors.white.withOpacity(0.16),
          borderRadius: AppRadius.mdRadius,
          border: isTop ? Border.all(color: medal.withOpacity(0.6)) : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTop) ...[
                  Icon(Icons.emoji_events_rounded, color: medal, size: 13),
                  const SizedBox(width: 3),
                ],
                Text(
                  rank.position == null ? '—' : '${rank.position}/${rank.outOf}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.label,
    required this.subject,
    required this.color,
    required this.icon,
  });

  final String label;
  final String subject;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: AppGradients.tint(color), borderRadius: AppRadius.smRadius),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SubjectBar extends StatelessWidget {
  const _SubjectBar({required this.subject, required this.color});

  final SubjectAverage subject;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = (subject.average / 10).clamp(0.0, 1.0);
    final initial = subject.subject.isNotEmpty ? subject.subject[0].toUpperCase() : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(gradient: AppGradients.tint(color), borderRadius: AppRadius.smRadius),
          child: Text(initial, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.subject,
                      style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.textPrimary, fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    subject.average.toStringAsFixed(1),
                    style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(height: 8, width: constraints.maxWidth, color: context.colors.surfaceSunken),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: fraction),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, animatedFraction, _) => Container(
                            height: 8,
                            width: constraints.maxWidth * animatedFraction,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: LinearGradient(colors: [color.withOpacity(0.7), color]),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttendanceRateCard extends StatelessWidget {
  const _AttendanceRateCard({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = rate >= 80
        ? context.colors.success
        : rate >= 60
            ? context.colors.warning
            : context.colors.danger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(gradient: AppGradients.tint(color), borderRadius: AppRadius.mdRadius),
            child: Icon(Icons.event_available_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.lessonAttendanceRate,
              style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.textPrimary),
            ),
          ),
          Text(
            '${rate.toStringAsFixed(0)}%',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color),
          ),
        ],
      ),
    );
  }
}

QuarterPoint? _pointForQuarter(List<QuarterPoint> trend, int quarter) {
  for (final point in trend) {
    if (point.quarter == quarter) return point;
  }
  return null;
}

/// How the pupil is doing, from two angles the same card can switch
/// between: across the school year's quarters, and across the days of the
/// quarter on screen.
///
/// A tab rather than two stacked cards because they answer the same
/// question at different zoom levels -- showing both at once would make the
/// page longer without making it clearer.
class _ComparisonTrendCard extends StatefulWidget {
  const _ComparisonTrendCard({required this.overview, required this.grades});

  final StudentAnalyticsOverview overview;
  final List<Grade> grades;

  @override
  State<_ComparisonTrendCard> createState() => _ComparisonTrendCardState();
}

class _ComparisonTrendCardState extends State<_ComparisonTrendCard> {
  bool _monthly = false;

  @override
  Widget build(BuildContext context) {
    final overview = widget.overview;
    final l10n = AppLocalizations.of(context)!;
    final comparisons = [
      if (overview.classAverage != null) (l10n.classAverage, overview.classAverage!),
      if (overview.parallelAverage != null) (l10n.parallelAverage, overview.parallelAverage!),
      if (overview.schoolAverage != null) (l10n.schoolAverage, overview.schoolAverage!),
    ];
    final own = overview.overallAverage;

    final currentTrendPoint = _pointForQuarter(overview.trend, overview.quarter);
    final previousTrendPoint = _pointForQuarter(overview.trend, overview.quarter - 1);
    final delta = (currentTrendPoint?.overallAverage != null && previousTrendPoint?.overallAverage != null)
        ? currentTrendPoint!.overallAverage! - previousTrendPoint!.overallAverage!
        : null;
    // Matches TrendSparkline's own "at least 2 non-null points" requirement
    // -- gating on the raw trend list length instead left an empty gap
    // (header shown, chart hidden) whenever most quarters had no grades yet.
    final hasTrendChart = overview.trend.where((p) => p.overallAverage != null).length > 1;

    // The monthly view walks its own months, so it isn't scoped to the
    // quarter the rest of the page is showing -- it just needs marks.
    final hasMonthly = widget.grades.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comparisons.isNotEmpty && own != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, avg) in comparisons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _ComparisonRow(label: label, ownValue: own, groupValue: avg),
                  ),
              ],
            ),
          if (comparisons.isNotEmpty && own != null && (hasTrendChart || hasMonthly))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
          // The switch only earns its place when there are actually two
          // views to switch between.
          if (hasTrendChart && hasMonthly) ...[
            _AnalysisTabs(
              monthly: _monthly,
              onChanged: (value) => setState(() => _monthly = value),
            ),
            const SizedBox(height: 14),
          ],
          if ((_monthly || !hasTrendChart) && hasMonthly)
            MonthlyTrendChart(grades: widget.grades)
          else if (hasTrendChart) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.trendVsPreviousQuarter,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
                  ),
                ),
                if (delta != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        delta >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 14,
                        color: delta >= 0 ? context.colors.success : context.colors.danger,
                      ),
                      Text(
                        delta.abs().toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: delta >= 0 ? context.colors.success : context.colors.danger,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TrendSparkline(points: overview.trend, color: context.colors.primary),
          ],
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.label, required this.ownValue, required this.groupValue});

  final String label;
  final double ownValue;
  final double groupValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final delta = ownValue - groupValue;
    final ahead = delta >= 0;
    final deltaColor = ahead ? colors.success : colors.danger;

    // Two bars on the school's own 0..10 scale, so "am I above or below
    // this group" is answered by their lengths before any number is read.
    // The figures alone made every row look the same at a glance.
    double fraction(double value) =>
        (value / kMaxGradeValue).clamp(0.02, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
            Text(
              groupValue.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: deltaColor.withValues(alpha: 0.12),
                borderRadius: AppRadius.smRadius,
              ),
              child: Text(
                '${ahead ? '+' : ''}${delta.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: deltaColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _MiniBar(fraction: fraction(ownValue), color: deltaColor, thick: true),
        const SizedBox(height: 3),
        _MiniBar(fraction: fraction(groupValue), color: colors.textMuted, thick: false),
      ],
    );
  }
}

/// One bar of the comparison. The pupil's own is the thicker of the pair,
/// so which line is theirs needs no legend.
class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.fraction, required this.color, required this.thick});

  final double fraction;
  final Color color;
  final bool thick;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Row(
        children: [
          Expanded(
            flex: (value * 1000).round().clamp(1, 1000),
            child: Container(
              height: thick ? 6 : 4,
              decoration: BoxDecoration(
                color: color.withValues(alpha: thick ? 0.9 : 0.45),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Expanded(
            flex: ((1 - value) * 1000).round().clamp(1, 1000),
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// The two-way switch inside the analysis card.
///
/// A pair of pills rather than a Material TabBar: it sits inside a card, so
/// a full-width tab strip with its own indicator would read as a second
/// navigation level on a page that already has one.
class _AnalysisTabs extends StatelessWidget {
  const _AnalysisTabs({required this.monthly, required this.onChanged});

  final bool monthly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.surfaceSunken,
        borderRadius: AppRadius.mdRadius,
      ),
      child: Row(
        children: [
          _AnalysisTab(
            label: l10n.analysisByQuarter,
            selected: !monthly,
            onTap: () => onChanged(false),
          ),
          _AnalysisTab(
            label: l10n.analysisByMonth,
            selected: monthly,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _AnalysisTab extends StatelessWidget {
  const _AnalysisTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.surface : Colors.transparent,
            borderRadius: AppRadius.smRadius,
            boxShadow: selected ? AppShadows.raised : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? colors.textPrimary : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
