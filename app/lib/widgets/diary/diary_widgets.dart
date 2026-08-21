import 'package:flutter/material.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../../core/design_tokens.dart';
import '../../models/lesson_schedule.dart';

/// Which lesson (if any) is happening right now, for [date] -- only
/// meaningful when [date] is today; used by [DiaryDayNavigator] to show
/// "Lesson N, ends at HH:MM" instead of a plain lesson count, matching a
/// school ruznoma's "where are we right now" readout.
class _CurrentLesson {
  const _CurrentLesson(this.index, this.endTime);
  final int index;
  final String endTime;
}

_CurrentLesson? _findCurrentLesson(List<DiaryEntry> entries, DateTime date) {
  final now = DateTime.now();
  final isToday = now.year == date.year && now.month == date.month && now.day == date.day;
  if (!isToday) return null;

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final parts = entry.startTime.split(':');
    if (parts.length != 2) continue;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) continue;

    final start = DateTime(now.year, now.month, now.day, hour, minute);
    final end = start.add(Duration(minutes: entry.durationMinutes));
    if (now.isAfter(start) && now.isBefore(end)) {
      final endTime = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
      return _CurrentLesson(i + 1, endTime);
    }
  }
  return null;
}

/// A premium gradient pill day-navigator: a rounded "pick a date" field
/// above a gradient bar with prev/next chevrons flanking the weekday + date
/// on the left and either the lesson count or (if viewing today) the
/// currently-running lesson + its end time on the right.
class DiaryDayNavigator extends StatelessWidget {
  const DiaryDayNavigator({
    super.key,
    required this.date,
    required this.entryCount,
    required this.entries,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
  });

  final DateTime date;
  final int entryCount;
  final List<DiaryEntry> entries;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  static const _weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  String _weekdayLabel(AppLocalizations l10n) {
    final labels = {
      'mon': l10n.weekday1,
      'tue': l10n.weekday2,
      'wed': l10n.weekday3,
      'thu': l10n.weekday4,
      'fri': l10n.weekday5,
      'sat': l10n.weekday6,
      'sun': l10n.weekday6,
    };
    return labels[_weekdayKeys[date.weekday - 1]] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = _findCurrentLesson(entries, date);
    final dateLabel = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    return Column(
      children: [
        Material(
          color: context.colors.surface,
          borderRadius: AppRadius.xlRadius,
          child: InkWell(
            borderRadius: AppRadius.xlRadius,
            onTap: onPickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: AppRadius.xlRadius,
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, size: 18, color: context.colors.textMuted),
                  const SizedBox(width: 10),
                  Text(
                    l10n.pickDatePrompt,
                    style: TextStyle(color: context.colors.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: AppRadius.xlRadius,
            boxShadow: AppShadows.colored(context.colors.primary),
          ),
          child: Row(
            children: [
              _NavArrow(icon: Icons.chevron_left_rounded, onTap: onPrevious),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      dateLabel,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      _weekdayLabel(l10n),
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      current != null ? '${current.index}-${l10n.lessonWord}' : '$entryCount ${l10n.lessonsCountSuffix}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    if (current != null)
                      Text(
                        l10n.untilTime(current.endTime),
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 11.5),
                      ),
                  ],
                ),
              ),
              _NavArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

Color _gradeColor(BuildContext context, int value) {
  if (value >= 9) return context.colors.success;
  if (value >= 7) return context.colors.info;
  if (value >= 5) return context.colors.warning;
  return context.colors.danger;
}

/// End of a lesson as "HH:MM", derived from its start time + duration --
/// the schedule only stores a start, but showing a range reads far quicker
/// than a start time plus a separate "45 min" figure.
String? _endTime(DiaryEntry entry) {
  final parts = entry.startTime.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  final total = hour * 60 + minute + entry.durationMinutes;
  final endHour = (total ~/ 60) % 24;
  final endMinute = total % 60;
  return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
}

/// A whole day of lessons as one page, the way a paper diary reads: a single
/// sheet with a numbered row per lesson, not a stack of separate floating
/// cards.
///
/// Three earlier attempts rendered each lesson as its own card. That made a
/// school day look like six unrelated items and left rows with and without
/// homework at wildly different heights. Here the day is one surface and the
/// lessons are its rows, separated by hairlines.
class DiaryDayPage extends StatelessWidget {
  const DiaryDayPage({
    super.key,
    required this.entries,
    this.canEdit,
    this.onTapEntry,
  });

  final List<DiaryEntry> entries;

  /// Asked per lesson, not once for the page: a teacher who takes only
  /// Maths in this class must not see an edit affordance on the Physics
  /// row. Null means nobody can edit (parent/student view).
  final bool Function(DiaryEntry entry)? canEdit;

  final ValueChanged<DiaryEntry>? onTapEntry;

  /// Index of the lesson happening right now, or -1. Entries carrying a date
  /// other than today are skipped, so browsing to another day never lights
  /// up a row as if it were live.
  int _currentIndex() {
    final now = DateTime.now();
    for (var i = 0; i < entries.length; i++) {
      final parts = entries[i].startTime.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      final logDate = entries[i].logDate;
      if (logDate != null &&
          (logDate.year != now.year ||
              logDate.month != now.month ||
              logDate.day != now.day)) {
        continue;
      }
      final start = DateTime(now.year, now.month, now.day, hour, minute);
      final end = start.add(Duration(minutes: entries[i].durationMinutes));
      if (now.isAfter(start) && now.isBefore(end)) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.colors.border),
            Builder(
              builder: (context) {
                final editable = canEdit?.call(entries[i]) ?? false;
                return _DiaryLessonRow(
                  entry: entries[i],
                  index: i + 1,
                  isNow: i == currentIndex,
                  editable: editable,
                  onTap: editable && onTapEntry != null
                      ? () => onTapEntry!(entries[i])
                      : null,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DiaryLessonRow extends StatelessWidget {
  const _DiaryLessonRow({
    required this.entry,
    required this.index,
    required this.isNow,
    required this.editable,
    this.onTap,
  });

  final DiaryEntry entry;
  final int index;
  final bool isNow;
  final bool editable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final homework = entry.homework;
    final comment = entry.teacherComment;
    final hasHomework = homework != null && homework.isNotEmpty;
    final hasComment = comment != null && comment.isNotEmpty;
    final endTime = _endTime(entry);

    final meta = [
      if (entry.teacherName != null && entry.teacherName!.isNotEmpty) entry.teacherName!,
      if (entry.room != null && entry.room!.isNotEmpty) entry.room!,
    ].join(' · ');

    final row = Container(
      // The lesson in progress gets a faint wash rather than a border or
      // badge, so it stands out without breaking the page grid.
      color: isNow ? context.colors.primary.withOpacity(0.06) : null,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Text(
                  '$index',
                  style: TextStyle(
                    color: isNow ? context.colors.primary : context.colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.startTime,
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (endTime != null)
                  Text(
                    endTime,
                    style: TextStyle(color: context.colors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.subject,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.2,
                  ),
                ),
                if (meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.colors.textMuted, fontSize: 12),
                    ),
                  ),
                // Homework is the reason a pupil opens the diary, so it gets
                // its own tinted strip instead of being one more grey line.
                if (hasHomework)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withOpacity(0.07),
                      borderRadius: AppRadius.smRadius,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.assignment_outlined, size: 14, color: context.colors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            homework,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (hasComment)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 13, color: context.colors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            comment,
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (editable && !hasHomework && !hasComment)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l10n.addHomeworkPrompt,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (entry.grade != null) ...[
            const SizedBox(width: 10),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _gradeColor(context, entry.grade!),
                borderRadius: AppRadius.smRadius,
              ),
              alignment: Alignment.center,
              child: Text(
                '${entry.grade}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ] else if (editable) ...[
            const SizedBox(width: 10),
            Icon(Icons.edit_outlined, size: 16, color: context.colors.textMuted),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
