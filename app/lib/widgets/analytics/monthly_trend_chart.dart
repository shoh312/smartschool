import 'package:flutter/material.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../../core/design_tokens.dart';
import '../../utils/date_formatters.dart';
import '../../models/grade.dart';

/// The school marks out of ten, so that is the axis. Anchoring at zero
/// keeps a bar's height proportional to the mark itself -- a 4 really is
/// twice a 2 -- instead of exaggerating small gaps.
const double kMaxGradeValue = 10.0;

/// One day of a month, with whatever marks landed on it.
class MonthDayPoint {
  const MonthDayPoint({required this.day, this.average, this.count = 0});

  final int day;

  /// Null on a day with no marks -- a gap in the chart, not a zero.
  final double? average;
  final int count;

  bool get hasMarks => average != null;
}

/// Every day of [month], in order, carrying that day's average mark.
///
/// Every day is present, including the empty ones: the point of a monthly
/// chart is the shape of the month, and squeezing out the blank days would
/// put two marks a fortnight apart side by side as though they were
/// consecutive.
List<MonthDayPoint> buildMonthPoints(List<Grade> grades, DateTime month) {
  final buckets = <int, List<int>>{};
  for (final grade in grades) {
    final date = grade.gradeDate;
    if (date.year != month.year || date.month != month.month) continue;
    buckets.putIfAbsent(date.day, () => []).add(grade.value);
  }

  final dayCount = DateTime(month.year, month.month + 1, 0).day;
  return [
    for (var day = 1; day <= dayCount; day++)
      MonthDayPoint(
        day: day,
        average: buckets[day] == null
            ? null
            : buckets[day]!.reduce((a, b) => a + b) / buckets[day]!.length,
        count: buckets[day]?.length ?? 0,
      ),
  ];
}

/// A month of marks as a bar per day, with arrows to walk back through
/// earlier months.
class MonthlyTrendChart extends StatefulWidget {
  const MonthlyTrendChart({super.key, required this.grades, this.height = 110});

  final List<Grade> grades;
  final double height;

  @override
  State<MonthlyTrendChart> createState() => _MonthlyTrendChartState();
}

class _MonthlyTrendChartState extends State<MonthlyTrendChart> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final points = buildMonthPoints(widget.grades, _month);
    final marked = points.where((p) => p.hasMarks).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ArrowButton(icon: Icons.chevron_left_rounded, onTap: () => _shift(-1)),
            Expanded(
              child: Text(
                DateFormatters.monthYear(l10n, _month),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            _ArrowButton(
              icon: Icons.chevron_right_rounded,
              // Nothing to see in the future; a mark can't be dated ahead.
              onTap: _isCurrentMonth ? null : () => _shift(1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (marked.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: Text(
                l10n.analysisNoMonthly,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ),
          )
        else ...[
          SizedBox(
            height: widget.height,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final point in points)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.8),
                        child: _DayBar(
                          fraction: point.hasMarks
                              ? (point.average! / kMaxGradeValue).clamp(0.05, 1.0) * progress
                              : 0,
                          color: _barColor(context, point.average),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('1', style: TextStyle(fontSize: 10.5, color: colors.textMuted)),
              const Spacer(),
              Text('${points.length}',
                  style: TextStyle(fontSize: 10.5, color: colors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Fact(
                label: l10n.average,
                value: (marked.map((p) => p.average!).reduce((a, b) => a + b) /
                        marked.length)
                    .toStringAsFixed(1),
                color: colors.primary,
              ),
              const SizedBox(width: 10),
              _Fact(
                label: l10n.analysisBestDay,
                value: _bestLabel(marked),
                color: colors.success,
              ),
              const SizedBox(width: 10),
              _Fact(
                label: l10n.grades,
                value: '${marked.fold<int>(0, (sum, p) => sum + p.count)}',
                color: colors.warning,
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _bestLabel(List<MonthDayPoint> marked) {
    final best = marked.reduce((a, b) => a.average! >= b.average! ? a : b);
    return '${best.day} · ${best.average!.toStringAsFixed(1)}';
  }

  Color _barColor(BuildContext context, double? average) {
    final colors = context.colors;
    if (average == null) return colors.border;
    if (average >= 9) return colors.success;
    if (average >= 7) return colors.primary;
    if (average >= 5) return colors.warning;
    return colors.danger;
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // An empty day still draws a hairline at the baseline, so the month
    // reads as a continuous run of days rather than a broken row of bars.
    if (fraction <= 0) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            color: context.colors.border,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      );
    }

    return FractionallySizedBox(
      alignment: Alignment.bottomCenter,
      heightFactor: fraction,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 22,
        color: enabled ? context.colors.textPrimary : context.colors.textMuted,
      ),
      onPressed: onTap,
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.mdRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
