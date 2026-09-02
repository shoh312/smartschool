import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../../core/design_tokens.dart';
import '../../models/attendance.dart';

/// Charts for the desktop dashboard, drawn from the live attendance feed.
///
/// Every colour here is a *status* colour -- came, late, missing -- not a
/// series identity, so it never varies with how many bars there happen to
/// be, and it never carries meaning alone: each mark is accompanied by its
/// icon and its number. That is the rule for status palettes, and it is also
/// what makes these readable on the light theme, where the greens and ambers
/// sit below 3:1 against the surface.
///
/// Nothing here needs a charting package. The shapes are simple enough to
/// paint directly, and painting them keeps the marks thin and the grid
/// recessive in a way most chart libraries fight.

/// One status and how many pupils are in it.
class StatusSlice {
  const StatusSlice({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;
}

/// Part-to-whole for the day, as one bar rather than a ring.
///
/// A donut would put the two numbers that actually get compared -- came and
/// missing -- on opposite sides of a circle, where a reader has to judge
/// angles. Side by side on one bar they are read by length, which is the
/// only comparison the eye does accurately.
class AttendanceSplitBar extends StatelessWidget {
  const AttendanceSplitBar({super.key, required this.slices});

  final List<StatusSlice> slices;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = slices.fold<int>(0, (sum, s) => sum + s.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            height: 14,
            // Stretched, not centred. A Row centres its children at their
            // own height by default, and a ColoredBox with no child is zero
            // tall -- so the bar rendered as nothing at all, leaving a card
            // with a title, a gap, and a legend for a bar nobody could see.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (total == 0)
                  Expanded(child: ColoredBox(color: colors.surfaceSunken))
                else
                  for (var i = 0; i < slices.length; i++)
                    if (slices[i].count > 0) ...[
                      Expanded(
                        flex: slices[i].count,
                        child: ColoredBox(color: slices[i].color),
                      ),
                      // A 2px gap of the surface, not a border: a stroke
                      // around each segment would thicken the bar and
                      // read as chrome.
                      if (i != slices.length - 1)
                        SizedBox(
                          width: 2,
                          child: ColoredBox(color: colors.surface),
                        ),
                    ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            for (final slice in slices)
              _LegendEntry(slice: slice, total: total),
          ],
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.slice, required this.total});

  final StatusSlice slice;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final percent = total == 0 ? 0 : (slice.count * 100 / total).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(slice.icon, size: 15, color: slice.color),
        const SizedBox(width: 7),
        Text(
          '${slice.count}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${slice.label} · $percent%',
          style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// A point on the arrival curve: how many had arrived by this minute.
class ArrivalPoint {
  const ArrivalPoint(this.at, this.arrived);

  final DateTime at;
  final int arrived;
}

/// Arrivals across the morning, as a cumulative curve.
///
/// One series, so no legend -- the title says what it is -- and only the
/// endpoint is labelled. A number beside every point would be unreadable
/// and would go unread.
class ArrivalTimelineChart extends StatefulWidget {
  const ArrivalTimelineChart({
    super.key,
    required this.points,
    required this.total,
    this.arrivedWithoutTime = false,
  });

  final List<ArrivalPoint> points;

  /// Somebody is marked as having arrived, but no record carries a time.
  /// Saying "nobody has come" then would contradict the header.
  final bool arrivedWithoutTime;

  /// The roster, so the curve is drawn against what it is climbing towards
  /// rather than against its own maximum.
  final int total;

  @override
  State<ArrivalTimelineChart> createState() => _ArrivalTimelineChartState();
}

class _ArrivalTimelineChartState extends State<ArrivalTimelineChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    if (widget.points.length < 2) {
      return _ChartEmptyState(
        icon: Icons.timeline_rounded,
        message: widget.arrivedWithoutTime
            ? l10n.dashArrivedNoTime
            : l10n.dashNobodyYet,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          onHover: (event) {
            final index = _indexAt(
              event.localPosition.dx,
              constraints.maxWidth,
            );
            if (index != _hoveredIndex) setState(() => _hoveredIndex = index);
          },
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: CustomPaint(
            // Sized to include the hour labels under the plot, so the card
            // never grows a nested scrollbar around a clipped axis.
            size: Size(constraints.maxWidth, 190),
            painter: _ArrivalPainter(
              points: widget.points,
              total: widget.total,
              hoveredIndex: _hoveredIndex,
              line: colors.primary,
              fill: colors.primary.withValues(alpha: 0.12),
              grid: colors.border,
              text: colors.textSecondary,
              strongText: colors.textPrimary,
              surface: colors.surface,
            ),
          ),
        );
      },
    );
  }

  int? _indexAt(double dx, double width) {
    const left = 34.0;
    const right = 12.0;
    final plot = width - left - right;
    if (plot <= 0) return null;
    final ratio = ((dx - left) / plot).clamp(0.0, 1.0);
    return (ratio * (widget.points.length - 1)).round();
  }
}

/// A smooth path through the points that never turns back on itself.
///
/// Fritsch-Carlson monotone cubic interpolation: the tangent at every point
/// is clamped so each segment stays monotonic between its neighbours. For a
/// cumulative count that is the whole requirement -- the line may flatten,
/// but it must never dip, and an ordinary spline dips wherever the data
/// levels off.
Path _monotonePath(List<double> xs, List<double> ys) {
  final path = Path();
  if (xs.isEmpty) return path;
  path.moveTo(xs.first, ys.first);
  if (xs.length == 1) return path;

  final n = xs.length;
  // Secant slopes between consecutive points.
  final secants = <double>[];
  for (var i = 0; i < n - 1; i++) {
    final dx = xs[i + 1] - xs[i];
    secants.add(dx == 0 ? 0 : (ys[i + 1] - ys[i]) / dx);
  }

  final tangents = <double>[secants.first];
  for (var i = 1; i < n - 1; i++) {
    // A flat neighbour on either side pins the tangent flat, which is what
    // stops the curve bulging through a stretch where nobody arrived.
    if (secants[i - 1] * secants[i] <= 0) {
      tangents.add(0);
    } else {
      tangents.add((secants[i - 1] + secants[i]) / 2);
    }
  }
  tangents.add(secants.last);

  for (var i = 0; i < n - 1; i++) {
    final dx = xs[i + 1] - xs[i];
    if (dx == 0) {
      path.lineTo(xs[i + 1], ys[i + 1]);
      continue;
    }
    // Clamped so the segment cannot overshoot its own endpoints.
    var m0 = tangents[i];
    var m1 = tangents[i + 1];
    if (secants[i] == 0) {
      m0 = 0;
      m1 = 0;
    } else {
      final a = m0 / secants[i];
      final b = m1 / secants[i];
      final h = a * a + b * b;
      if (h > 9) {
        final t = 3 / math.sqrt(h);
        m0 = t * a * secants[i];
        m1 = t * b * secants[i];
      }
    }
    path.cubicTo(
      xs[i] + dx / 3,
      ys[i] + m0 * dx / 3,
      xs[i + 1] - dx / 3,
      ys[i + 1] - m1 * dx / 3,
      xs[i + 1],
      ys[i + 1],
    );
  }
  return path;
}

class _ArrivalPainter extends CustomPainter {
  _ArrivalPainter({
    required this.points,
    required this.total,
    required this.hoveredIndex,
    required this.line,
    required this.fill,
    required this.grid,
    required this.text,
    required this.strongText,
    required this.surface,
  });

  final List<ArrivalPoint> points;
  final int total;
  final int? hoveredIndex;
  final Color line;
  final Color fill;
  final Color grid;
  final Color text;
  final Color strongText;
  final Color surface;

  static const _left = 34.0;
  static const _right = 12.0;
  static const _axisBand = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - _left - _right;
    final plotHeight = size.height - _axisBand - 10;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    final maxValue = math.max(total, points.last.arrived);
    double xFor(int i) => _left + plotWidth * (i / (points.length - 1));
    double yFor(int v) =>
        10 + plotHeight - (maxValue == 0 ? 0 : plotHeight * (v / maxValue));

    // Hairline grid, solid and one shade off the surface. Dashes would read
    // as a threshold; this is only a reference.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var step = 0; step <= 2; step++) {
      final value = (maxValue * step / 2).round();
      final y = yFor(value);
      canvas.drawLine(
        Offset(_left, y),
        Offset(size.width - _right, y),
        gridPaint,
      );
      _label(canvas, '$value', Offset(0, y - 6), text, 10.5);
    }

    // Smoothed, but only in a way that cannot lie.
    //
    // This started as a staircase, on the reasoning that pupils arrive at
    // moments and a curve through them invents somebody walking in between.
    // True, and beside the point at forty-odd arrivals: the steps stopped
    // being information and became texture.
    //
    // The smoothing is monotone cubic (Fritsch-Carlson), not the usual
    // Catmull-Rom, because this is a running total and a running total never
    // goes down. An ordinary spline overshoots around a flat stretch and
    // draws a dip -- a picture of pupils un-arriving.
    final xs = [for (var i = 0; i < points.length; i++) xFor(i)];
    final ys = [for (final point in points) yFor(point.arrived)];
    final path = _monotonePath(xs, ys);

    final area = Path.from(path)
      ..lineTo(xFor(points.length - 1), 10 + plotHeight)
      ..lineTo(xFor(0), 10 + plotHeight)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Only the endpoint is labelled.
    final endX = xFor(points.length - 1);
    final endY = yFor(points.last.arrived);
    canvas.drawCircle(Offset(endX, endY), 4.5, Paint()..color = line);
    canvas.drawCircle(
      Offset(endX, endY),
      4.5,
      Paint()
        ..color = surface
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    _label(
      canvas,
      _clock(points.first.at),
      Offset(_left - 12, size.height - 16),
      text,
      10.5,
    );
    _label(
      canvas,
      _clock(points.last.at),
      Offset(size.width - _right - 34, size.height - 16),
      text,
      10.5,
    );

    final index = hoveredIndex;
    if (index != null && index >= 0 && index < points.length) {
      final hx = xFor(index);
      canvas.drawLine(
        Offset(hx, 10),
        Offset(hx, 10 + plotHeight),
        Paint()
          ..color = grid
          ..strokeWidth = 1,
      );
      final point = points[index];
      final label = '${_clock(point.at)}  ·  ${point.arrived}';
      _tooltip(canvas, size, Offset(hx, yFor(point.arrived)), label);
    }
  }

  void _tooltip(Canvas canvas, Size size, Offset anchor, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 11.5,
          color: surface,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final width = painter.width + 16;
    final left = (anchor.dx - width / 2).clamp(0.0, size.width - width);
    final top = math.max(0.0, anchor.dy - 32);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, 24),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = strongText.withValues(alpha: 0.92));
    painter.paint(canvas, Offset(left + 8, top + 5));
  }

  void _label(
    Canvas canvas,
    String value,
    Offset at,
    Color color,
    double size,
  ) {
    TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(fontSize: size, color: color),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, at);
  }

  static String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  @override
  bool shouldRepaint(_ArrivalPainter old) =>
      old.points != points ||
      old.hoveredIndex != hoveredIndex ||
      old.total != total ||
      old.line != line;
}

/// One class and how much of it turned up.
class ClassAttendance {
  const ClassAttendance({
    required this.name,
    required this.present,
    required this.total,
    this.state = LessonState.none,
  });

  final String name;
  final int present;
  final int total;

  /// Where today's lesson for this group stands. Shown as words beside the
  /// bar in group mode, because "0 present" means something entirely
  /// different for a group that has not started than for one that is over.
  final LessonState state;

  double get rate => total == 0 ? 0 : present / total;
}

/// Attendance per class, as horizontal bars.
///
/// Sorted worst-first: the reason a director opens this panel is to find
/// the class that is missing people, and putting it at the top means never
/// having to scan for it.
class ClassAttendanceBars extends StatefulWidget {
  const ClassAttendanceBars({
    super.key,
    required this.rows,
    this.maxRows = 8,
    required this.emptyMessage,
  });

  final List<ClassAttendance> rows;

  /// How many fit before the list needs a "show the rest" control. A school
  /// with thirty classes would otherwise push every panel below it off the
  /// screen, and this one exists to be glanced at.
  final int maxRows;

  final String emptyMessage;

  @override
  State<ClassAttendanceBars> createState() => _ClassAttendanceBarsState();
}

class _ClassAttendanceBarsState extends State<ClassAttendanceBars> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (widget.rows.isEmpty) {
      return _ChartEmptyState(
        icon: Icons.bar_chart_rounded,
        message: widget.emptyMessage,
      );
    }

    final sorted = List.of(widget.rows)
      ..sort((a, b) => a.rate.compareTo(b.rate));
    final hidden = sorted.length - widget.maxRows;
    final shown = _showAll ? sorted : sorted.take(widget.maxRows).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ClassBar(row: row, colors: colors),
          ),
        if (hidden > 0)
          TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _showAll
                  ? AppLocalizations.of(context)!.dashShowLess
                  : AppLocalizations.of(context)!.dashMoreClasses(hidden),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _ClassBar extends StatelessWidget {
  const _ClassBar({required this.row, required this.colors});

  final ClassAttendance row;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    // The colour says how the class is doing; the numbers beside it say the
    // same thing in words, so the bar is never the only carrier.
    final color = row.rate >= 0.9
        ? colors.success
        : row.rate >= 0.7
        ? colors.warning
        : colors.danger;

    return Tooltip(
      message: '${row.name}: ${row.present}/${row.total}',
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              row.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
            ),
          ),
          // Where today's lesson stands, in words. "0 present" for a group
          // that has not started yet and one whose lesson is over are the
          // same number and completely different news, and the bar alone
          // cannot tell them apart.
          if (row.state != LessonState.none) ...[
            _LessonStateChip(state: row.state, colors: colors),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    ColoredBox(
                      color: colors.surfaceSunken,
                      child: const SizedBox.expand(),
                    ),
                    // heightFactor as well as widthFactor. Without it the
                    // fill is given a width and left to find its own height,
                    // and a ColoredBox with no child is zero tall -- so the
                    // bar never appeared to move no matter what the numbers
                    // beside it said.
                    FractionallySizedBox(
                      widthFactor: row.rate.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: ColoredBox(color: color),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Outside the bar end, never inside it: a short bar cannot hold a
          // label without clipping it.
          SizedBox(
            width: 54,
            child: Text(
              '${row.present}/${row.total}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 140,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: colors.textMuted),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 12.5, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's lesson, in a word and an icon.
///
/// Deliberately not colour alone: "running" green and "finished" grey are
/// the sort of pair a reader guesses wrong at a glance, and on the light
/// theme the greens sit below 3:1 against the card anyway.
class _LessonStateChip extends StatelessWidget {
  const _LessonStateChip({required this.state, required this.colors});

  final LessonState state;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, icon, color) = switch (state) {
      LessonState.running => (
        l10n.dashLessonRunning,
        Icons.play_circle_rounded,
        colors.success,
      ),
      LessonState.upcoming => (
        l10n.dashLessonUpcoming,
        Icons.schedule_rounded,
        colors.textMuted,
      ),
      LessonState.finished => (
        l10n.dashLessonFinished,
        Icons.check_circle_outline_rounded,
        colors.textSecondary,
      ),
      LessonState.none => ('', Icons.remove, colors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
