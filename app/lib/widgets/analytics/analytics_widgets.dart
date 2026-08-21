import 'package:flutter/material.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../../core/design_tokens.dart';
import '../../models/analytics.dart';

/// Shared medal styling for a 1st/2nd/3rd place position -- used by both
/// [RankingListScreen]'s leaderboard rows and [StudentAnalyticsScreen]'s
/// rank badges, so a "gold" rank always looks the same gold everywhere
/// instead of two screens picking slightly different colors.
class RankColors {
  RankColors._();

  static const gold = Color(0xFFD4AF37);
  static const silver = Color(0xFFA0A5AD);
  static const bronze = Color(0xFFB4732C);

  static Color forPosition(BuildContext context, int? position) {
    switch (position) {
      case 1:
        return gold;
      case 2:
        return silver;
      case 3:
        return bronze;
      default:
        return context.colors.textMuted;
    }
  }

  static bool isTopThree(int? position) => position != null && position <= 3;
}

/// A short, upbeat label for a notable rank -- "1-o'rin", "TOP-3", or
/// "TOP-10%" for a strong-but-not-podium position. Returns null when the
/// rank isn't notable enough to call out, so callers can skip rendering.
String? achievementLabel(AppLocalizations l10n, RankInfo rank) {
  final position = rank.position;
  if (position == null || rank.outOf <= 1) return null;
  if (position == 1) return l10n.achievementFirstPlace;
  if (position <= 3) return l10n.achievementTopThree;
  if (position / rank.outOf <= 0.1) return l10n.achievementTopTenPercent;
  return null;
}

/// A small gold-gradient pill for a notable rank -- purely decorative, reads
/// straight off [RankInfo] already on the wire (no backend change needed).
class AchievementRibbon extends StatelessWidget {
  const AchievementRibbon({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [RankColors.gold, Color(0xFFF4D160)],
        ),
        borderRadius: AppRadius.smRadius,
        boxShadow: [
          BoxShadow(color: RankColors.gold.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Counts up from 0 to [value] once, instead of the number just snapping in
/// -- a cheap, high-perceived-polish touch for hero numbers (overall
/// average, rank positions).
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    this.decimals = 2,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final int decimals;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => Text(animated.toStringAsFixed(decimals), style: style),
    );
  }
}

/// A tiny hand-drawn line chart of a student's overall average across
/// quarters -- no charting package, just a CustomPainter, consistent with
/// the rest of the app's hand-rolled visuals. Quarters with no average
/// (student wasn't graded yet that quarter) are skipped, not drawn as 0.
class TrendSparkline extends StatelessWidget {
  const TrendSparkline({super.key, required this.points, required this.color, this.height = 40});

  final List<QuarterPoint> points;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final values = points.where((p) => p.overallAverage != null).toList();
    if (values.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => CustomPaint(
          painter: _SparklinePainter(values: values, color: color, progress: progress),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color, required this.progress});

  final List<QuarterPoint> values;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final minValue = values.map((p) => p.overallAverage!).reduce((a, b) => a < b ? a : b);
    final maxValue = values.map((p) => p.overallAverage!).reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.01 ? 1.0 : maxValue - minValue;

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1);
      final normalized = (values[i].overallAverage! - minValue) / range;
      final y = size.height - (normalized * size.height * 0.8) - size.height * 0.1;
      points.add(Offset(x, y));
    }

    final visibleCount = (points.length * progress).ceil().clamp(1, points.length);
    final visiblePoints = points.sublist(0, visibleCount);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(visiblePoints.first.dx, visiblePoints.first.dy);
    for (final point in visiblePoints.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = color;
    for (final point in visiblePoints) {
      canvas.drawCircle(point, 2.6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.values != values;
}

/// Fades and slides [child] in once, [delay] after this widget first
/// builds -- used to stagger a screen's sections in one after another
/// instead of everything popping in at once. Pure Flutter, no animation
/// package, consistent with the rest of the app's hand-rolled motion.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.06),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
