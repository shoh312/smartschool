import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import '../../models/analytics.dart';

/// A class's per-subject averages as a radar (spider) chart.
///
/// A row of bars answers "how good is maths?" one subject at a time. The
/// point of this screen is the shape of the whole class -- which corner is
/// caving in -- and that is what a closed polygon shows at a glance: an even
/// class is a regular shape, a class with one weak subject has a visible
/// dent pointing straight at it.
///
/// Hand-painted like every other chart in the app ([MonthlyTrendChart],
/// [TrendSparkline]) rather than pulling in a charting package for one
/// screen.
class SubjectRadarChart extends StatelessWidget {
  const SubjectRadarChart({
    super.key,
    required this.subjects,
    this.height = 250,
  });

  final List<ClassSubjectAverage> subjects;
  final double height;

  /// Below three axes a radar is not a shape -- two subjects draw a line,
  /// one draws a dot. Callers show the bar list instead.
  static const int minSubjects = 3;

  /// Marks are out of ten, so the outer ring is ten. Anchored at zero for
  /// the same reason the bars are: a 4 has to look like half of an 8.
  static const double maxGrade = 10;

  /// More axes than this and the labels collide; the weakest subjects are
  /// the ones worth keeping, plus the strongest for contrast.
  static const int maxAxes = 8;

  List<ClassSubjectAverage> get _axes {
    if (subjects.length <= maxAxes) return subjects;
    // Server order is strongest-first: keep the top few and the bottom few,
    // which is what a reader is looking for anyway.
    const head = maxAxes ~/ 2;
    return [
      ...subjects.take(head),
      ...subjects.skip(subjects.length - (maxAxes - head)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final axes = _axes;
    if (axes.length < minSubjects) return const SizedBox.shrink();

    final average =
        axes.map((s) => s.average).reduce((a, b) => a + b) / axes.length;
    final fill = average >= 8
        ? context.colors.success
        : average >= 6
            ? context.colors.warning
            : context.colors.danger;

    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => CustomPaint(
          size: Size.infinite,
          painter: _RadarPainter(
            subjects: axes,
            progress: progress,
            fill: fill,
            grid: context.colors.border,
            gridStrong: context.colors.textMuted,
            label: context.colors.textSecondary,
            value: context.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.subjects,
    required this.progress,
    required this.fill,
    required this.grid,
    required this.gridStrong,
    required this.label,
    required this.value,
  });

  final List<ClassSubjectAverage> subjects;
  final double progress;
  final Color fill;
  final Color grid;
  final Color gridStrong;
  final Color label;
  final Color value;

  /// Rings drawn behind the shape, so a reader can tell a 6 from an 8
  /// without a numeric axis cluttering the middle.
  static const _rings = [2.0, 4.0, 6.0, 8.0, 10.0];

  /// Room reserved outside the outermost ring for the subject labels.
  static const _labelGutter = 46.0;

  Offset _pointAt(Offset center, double radius, int index, double fraction) {
    // Starts at twelve o'clock and runs clockwise, which is how a reader
    // expects to walk round a dial.
    final angle = -math.pi / 2 + (2 * math.pi * index) / subjects.length;
    return Offset(
      center.dx + math.cos(angle) * radius * fraction,
      center.dy + math.sin(angle) * radius * fraction,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - _labelGutter;
    if (radius <= 0) return;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;

    for (final ring in _rings) {
      final fraction = ring / SubjectRadarChart.maxGrade;
      // The outer ring is the scale's edge and carries a little more weight
      // than the guides inside it.
      ringPaint.color = ring == _rings.last ? gridStrong.withOpacity(0.45) : grid;
      final path = Path();
      for (var i = 0; i < subjects.length; i++) {
        final point = _pointAt(center, radius, i, fraction);
        i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, ringPaint);
    }

    // Spokes
    final spokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;
    for (var i = 0; i < subjects.length; i++) {
      canvas.drawLine(center, _pointAt(center, radius, i, 1), spokePaint);
    }

    // The class's own shape.
    final shape = Path();
    for (var i = 0; i < subjects.length; i++) {
      final fraction =
          (subjects[i].average / SubjectRadarChart.maxGrade).clamp(0.0, 1.0) * progress;
      final point = _pointAt(center, radius, i, fraction);
      i == 0 ? shape.moveTo(point.dx, point.dy) : shape.lineTo(point.dx, point.dy);
    }
    shape.close();

    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.fill
        ..color = fill.withOpacity(0.22),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = fill,
    );

    // Vertices, so each subject has a point to read the label against.
    for (var i = 0; i < subjects.length; i++) {
      final fraction =
          (subjects[i].average / SubjectRadarChart.maxGrade).clamp(0.0, 1.0) * progress;
      final point = _pointAt(center, radius, i, fraction);
      canvas.drawCircle(point, 4, Paint()..color = fill);
      canvas.drawCircle(
        point,
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withOpacity(0.85),
      );
    }

    if (progress < 1) return; // Labels only once the shape has settled.

    for (var i = 0; i < subjects.length; i++) {
      _paintLabel(canvas, center, radius, i, size);
    }
  }

  void _paintLabel(Canvas canvas, Offset center, double radius, int index, Size size) {
    final anchor = _pointAt(center, radius + 16, index, 1);
    final subject = subjects[index];

    final painter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${subject.subject}\n',
            style: TextStyle(
              color: label,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          TextSpan(
            text: subject.average.toStringAsFixed(1),
            style: TextStyle(
              color: value,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 78);

    // Centre the label on its spoke, then pull it back inside the canvas so
    // a subject sitting due east or west can't be clipped by the edge.
    var dx = anchor.dx - painter.width / 2;
    var dy = anchor.dy - painter.height / 2;
    dx = dx.clamp(0.0, math.max(0.0, size.width - painter.width));
    dy = dy.clamp(0.0, math.max(0.0, size.height - painter.height));

    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.progress != progress ||
      old.subjects != subjects ||
      old.fill != fill;
}
