import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/grade.dart';
import '../providers/journal_provider.dart';
import '../utils/date_formatters.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_card.dart';

const double _kSubjectColumnWidth = 140;
const double _kDateColumnWidth = 44;
const double _kRowHeight = 58;

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

int _daysInMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 0).day;

bool _isWeekend(DateTime date) =>
    date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

Color _gradeColor(BuildContext context, int value) {
  if (value >= 9) return context.colors.success;
  if (value >= 7) return context.colors.info;
  if (value >= 5) return context.colors.warning;
  return context.colors.danger;
}

/// Read-only monthly journal for a single student -- same grid presentation
/// teachers/directors see for a whole class, but rows are the student's
/// subjects instead of classmates (a parent must never see other students'
/// grades, so this stays a dedicated screen rather than reusing
/// ClassJournalScreen with a one-row roster).
class StudentJournalScreen extends StatefulWidget {
  const StudentJournalScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.parentId,
  });

  final int studentId;
  final String studentName;
  final int? parentId;

  @override
  State<StudentJournalScreen> createState() => _StudentJournalScreenState();
}

class _StudentJournalScreenState extends State<StudentJournalScreen> {
  late DateTime _viewedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewedMonth = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JournalProvider>().loadForStudent(
        widget.studentId,
        parentId: widget.parentId,
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

  void _showGradeDetails(String subject, Grade grade) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.colors.borderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _gradeColor(context, grade.value).withOpacity(0.15),
                      borderRadius: AppRadius.mdRadius,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      grade.value.toString(),
                      style: TextStyle(
                        color: _gradeColor(context, grade.value),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          _dateKey(grade.gradeDate),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                l10n.journalTeacherLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                grade.teacherName ?? '-',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.journalCommentOptional,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                (grade.comment == null || grade.comment!.isEmpty)
                    ? l10n.journalNoComment
                    : grade.comment!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdRadius,
                  ),
                ),
                child: Text(l10n.close),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final journal = context.watch<JournalProvider>();
    final theme = Theme.of(context);
    final today = _dateOnly(DateTime.now());
    final monthLabel = DateFormatters.monthYear(l10n, _viewedMonth);

    final subjects = journal.grades.map((g) => g.subject).toSet().toList()
      ..sort();

    final dateColumns = [
      for (var day = 1; day <= _daysInMonth(_viewedMonth); day++)
        DateTime(_viewedMonth.year, _viewedMonth.month, day),
    ];

    final monthGrades = journal.grades.where((grade) {
      final date = _dateOnly(grade.gradeDate);
      return date.year == _viewedMonth.year && date.month == _viewedMonth.month;
    }).toList();
    final averageLabel = monthGrades.isEmpty
        ? '-'
        : (monthGrades.map((g) => g.value).reduce((a, b) => a + b) /
                  monthGrades.length)
              .toStringAsFixed(1);

    final gradesBySubjectAndDate = <String, Map<String, Grade>>{};
    for (final grade in journal.grades) {
      gradesBySubjectAndDate.putIfAbsent(
        grade.subject,
        () => {},
      )[_dateKey(grade.gradeDate)] = grade;
    }

    return AppShell(
      title: widget.studentName,
      child: RefreshIndicator(
        onRefresh: () => context.read<JournalProvider>().loadForStudent(
          widget.studentId,
          parentId: widget.parentId,
        ),
        child: journal.isLoading && journal.grades.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : subjects.isEmpty
            ? EmptyState(
                icon: Icons.grade_outlined,
                title: l10n.noGrades,
                message: l10n.noGradesMessage,
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: MetricCard(
                              label: l10n.subjectsLabel,
                              value: subjects.length.toString(),
                              imageAsset: 'assets/icons/subjects.png',
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MetricCard(
                              label: l10n.grades,
                              value: monthGrades.length.toString(),
                              imageAsset: 'assets/icons/grades.png',
                              color: context.colors.success,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MetricCard(
                              label: l10n.average,
                              value: averageLabel,
                              imageAsset: 'assets/icons/average.png',
                              color: context.colors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: AppRadius.lgRadius,
                        border: Border.all(color: context.colors.border),
                        boxShadow: AppShadows.card,
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
                            onPressed: _isCurrentMonth
                                ? null
                                : () => _changeMonth(1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final totalGridWidth =
                            dateColumns.length * _kDateColumnWidth;
                        final availableGridWidth =
                            (constraints.maxWidth - _kSubjectColumnWidth - 48)
                                .clamp(0.0, double.infinity);
                        final gridViewportWidth =
                            totalGridWidth < availableGridWidth
                            ? totalGridWidth
                            : availableGridWidth;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: AppRadius.lgRadius,
                              border: Border.all(color: context.colors.border),
                              boxShadow: AppShadows.card,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: _kSubjectColumnWidth,
                                  child: Column(
                                    children: [
                                      _HeaderCell(
                                        height: _kRowHeight,
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          child: Text(
                                            l10n.subjectLabel,
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  color: context.colors.primary,
                                                ),
                                          ),
                                        ),
                                      ),
                                      for (final entry
                                          in subjects.asMap().entries)
                                        Container(
                                          height: _kRowHeight,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          alignment: Alignment.centerLeft,
                                          decoration: BoxDecoration(
                                            color: entry.key.isOdd
                                                ? context.colors.surfaceAlt
                                                : context.colors.surface,
                                            border: Border(
                                              top: BorderSide(
                                                color: context.colors.border,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            entry.value,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      context.colors.textPrimary,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: gridViewportWidth,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            for (final date in dateColumns)
                                              _HeaderCell(
                                                width: _kDateColumnWidth,
                                                height: _kRowHeight,
                                                isToday: date == today,
                                                isWeekend: _isWeekend(date),
                                                child: Text(
                                                  '${date.day}',
                                                  style: theme
                                                      .textTheme.labelMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            date == today
                                                            ? FontWeight.bold
                                                            : FontWeight.w600,
                                                        color: date == today
                                                            ? context.colors.primary
                                                            : _isWeekend(date)
                                                            ? context.colors
                                                                  .textMuted
                                                            : context.colors
                                                                  .textSecondary,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        for (final entry
                                            in subjects.asMap().entries)
                                          Row(
                                            children: [
                                              for (final date in dateColumns)
                                                _ReadOnlyGradeCell(
                                                  grade:
                                                      gradesBySubjectAndDate[entry
                                                          .value]?[_dateKey(
                                                        date,
                                                      )],
                                                  isWeekend: _isWeekend(date),
                                                  zebra: entry.key.isOdd,
                                                  onTap: (grade) =>
                                                      _showGradeDetails(
                                                        entry.value,
                                                        grade,
                                                      ),
                                                ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    this.width,
    required this.height,
    this.alignment = Alignment.center,
    this.isToday = false,
    this.isWeekend = false,
    required this.child,
  });

  final double? width;
  final double height;
  final Alignment alignment;
  final bool isToday;
  final bool isWeekend;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: alignment,
      decoration: BoxDecoration(
        color: isToday
            ? context.colors.primary.withOpacity(0.08)
            : isWeekend
            ? context.colors.surfaceAlt
            : context.colors.primary.withOpacity(0.03),
        border: Border(
          bottom: BorderSide(color: context.colors.border, width: 1.5),
        ),
      ),
      child: child,
    );
  }
}

class _ReadOnlyGradeCell extends StatelessWidget {
  const _ReadOnlyGradeCell({
    required this.grade,
    required this.isWeekend,
    required this.zebra,
    required this.onTap,
  });

  final Grade? grade;
  final bool isWeekend;
  final bool zebra;
  final ValueChanged<Grade> onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isWeekend
        ? context.colors.surfaceAlt
        : zebra
        ? context.colors.surfaceAlt.withOpacity(0.6)
        : context.colors.surface;

    final grade = this.grade;

    final cell = Center(
      child: grade == null
          ? null
          : Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _gradeColor(context, grade.value).withOpacity(0.15),
                borderRadius: AppRadius.smRadius,
              ),
              alignment: Alignment.center,
              child: Text(
                grade.value.toString(),
                style: TextStyle(
                  color: _gradeColor(context, grade.value),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
    );

    return Container(
      width: _kDateColumnWidth,
      height: _kRowHeight,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: grade == null
          ? cell
          : InkWell(
              onTap: () => onTap(grade),
              borderRadius: AppRadius.smRadius,
              child: cell,
            ),
    );
  }
}
