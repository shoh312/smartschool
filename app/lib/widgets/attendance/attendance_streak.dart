import 'package:flutter/material.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../../core/design_tokens.dart';
import '../../models/attendance.dart';

/// How many school days in a row the pupil turned up.
///
/// Counted over the days the school actually recorded: a record only exists
/// where a lesson was scheduled, so weekends and holidays drop out on their
/// own rather than needing a calendar of their own.
///
/// Arriving late still counts as arriving, and so does leaving early -- both
/// mean the child was at school. Only an absence breaks a run. Anything
/// stricter would turn one late morning into a reason to stop trying, which
/// is the opposite of what a streak is for.
class AttendanceStreak {
  const AttendanceStreak({
    required this.current,
    required this.best,
    required this.daysCounted,
  });

  /// Days in the run ending at the most recent record.
  final int current;

  /// The longest run anywhere in the loaded history.
  final int best;

  /// How many recorded days the two numbers were drawn from -- a streak of
  /// 3 out of 3 days is not yet an achievement, and the UI says so.
  final int daysCounted;

  bool get isEmpty => daysCounted == 0;
}

bool _came(AttendanceStatus status) =>
    status == AttendanceStatus.present ||
    status == AttendanceStatus.late ||
    status == AttendanceStatus.leftSchool;

/// Folds a history into its streaks. Order of the input does not matter --
/// the API returns newest first, but nothing here should depend on that.
AttendanceStreak computeAttendanceStreak(List<AttendanceRecord> history) {
  // One record per day: a day with several rows (a re-detection after
  // leaving, say) must not count as several days of the streak.
  final byDay = <DateTime, AttendanceRecord>{};
  for (final record in history) {
    final day = DateTime(
      record.attendanceDate.year,
      record.attendanceDate.month,
      record.attendanceDate.day,
    );
    final existing = byDay[day];
    // Keep the day's best outcome: present beats a stray absent row.
    if (existing == null || (!_came(existing.status) && _came(record.status))) {
      byDay[day] = record;
    }
  }

  final days = byDay.keys.toList()..sort();
  if (days.isEmpty) {
    return const AttendanceStreak(current: 0, best: 0, daysCounted: 0);
  }

  var run = 0;
  var best = 0;
  for (final day in days) {
    if (_came(byDay[day]!.status)) {
      run += 1;
      if (run > best) best = run;
    } else {
      run = 0;
    }
  }

  return AttendanceStreak(current: run, best: best, daysCounted: days.length);
}

/// The streak, as the first thing on the attendance page.
///
/// A calendar answers "which day?"; this answers "how am I doing?" -- and
/// that is the question a pupil actually opens the page with.
class AttendanceStreakCard extends StatelessWidget {
  const AttendanceStreakCard({super.key, required this.streak});

  final AttendanceStreak streak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final alive = streak.current > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // A broken streak is not a failure state, so it gets a calm surface
        // rather than the danger colour: the number is already the message.
        gradient: alive ? AppGradients.success : null,
        color: alive ? null : context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: alive ? null : Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // A near-white disc while the streak is running, so the flame
              // reads as flame: an orange icon straight on the green would
              // fight it instead of sitting in it.
              color: alive
                  ? Colors.white.withOpacity(0.92)
                  : context.colors.surfaceSunken,
              shape: BoxShape.circle,
            ),
            child: alive
                ? const _FlameIcon(size: 30)
                : Icon(
                    Icons.local_fire_department_outlined,
                    size: 28,
                    color: context.colors.textMuted,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      streak.current.toString(),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        color: alive ? Colors.white : context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.streakDaysInARow,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: alive
                            ? Colors.white
                            : context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  streak.current == 0
                      ? l10n.streakStartToday
                      : l10n.streakBest(streak.best),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: alive ? Colors.white70 : context.colors.textMuted,
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

/// The flame, in flame colours.
///
/// A single flat orange looks like a sticker; a real flame is yellow at the
/// tip and deep orange at the base, so the icon is painted through a
/// gradient rather than given a colour.
class _FlameIcon extends StatelessWidget {
  const _FlameIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFBBF24), // amber 400 -- the tip
          Color(0xFFF97316), // orange 500
          Color(0xFFEF4444), // red 500 -- the base
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(bounds),
      child: Icon(
        Icons.local_fire_department_rounded,
        size: size,
        color: Colors.white,
      ),
    );
  }
}
