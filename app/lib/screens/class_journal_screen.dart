import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/grade.dart';
import '../providers/journal_provider.dart';
import '../providers/student_provider.dart';
import '../utils/date_formatters.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_card.dart';

const double _kNameColumnWidth = 168;
const double _kDateColumnWidth = 44;
const double _kRowHeight = 58;

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

int _daysInMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 0).day;

bool _isWeekend(DateTime date) =>
    date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

Color _gradeColor(int value) {
  if (value >= 9) return AppColors.success;
  if (value >= 7) return AppColors.info;
  if (value >= 5) return AppColors.warning;
  return AppColors.danger;
}

class ClassJournalScreen extends StatefulWidget {
  const ClassJournalScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  final int classId;
  final String className;

  @override
  State<ClassJournalScreen> createState() => _ClassJournalScreenState();
}

class _ClassJournalScreenState extends State<ClassJournalScreen> {
  late DateTime _viewedMonth;
  String? _selectedSubject;

  void _showGradeDetails(String studentName, Grade grade) {
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
          decoration: const BoxDecoration(
            color: AppColors.surface,
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
                    color: AppColors.borderStrong,
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
                      color: _gradeColor(grade.value).withOpacity(0.15),
                      borderRadius: AppRadius.mdRadius,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      grade.value.toString(),
                      style: TextStyle(
                        color: _gradeColor(grade.value),
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
                          studentName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          _dateKey(grade.gradeDate),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
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
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewedMonth = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JournalProvider>().loadForClass(widget.classId);
      context.read<StudentProvider>().loadStudents();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final journal = context.watch<JournalProvider>();
    final roster = context
        .watch<StudentProvider>()
        .students
        .where((student) => student.classId == widget.classId)
        .toList();
    final theme = Theme.of(context);
    final today = _dateOnly(DateTime.now());
    final monthLabel = DateFormatters.monthYear(l10n, _viewedMonth);

    final subjects = journal.grades.map((g) => g.subject).toSet().toList()
      ..sort();
    final effectiveSubject = subjects.contains(_selectedSubject)
        ? _selectedSubject
        : (subjects.isNotEmpty ? subjects.first : null);

    final subjectGrades = effectiveSubject == null
        ? const <Grade>[]
        : journal.grades.where((g) => g.subject == effectiveSubject).toList();

    final dateColumns = [
      for (var day = 1; day <= _daysInMonth(_viewedMonth); day++)
        DateTime(_viewedMonth.year, _viewedMonth.month, day),
    ];

    final monthGrades = subjectGrades.where((grade) {
      final date = _dateOnly(grade.gradeDate);
      return date.year == _viewedMonth.year && date.month == _viewedMonth.month;
    }).toList();
    final averageLabel = monthGrades.isEmpty
        ? '-'
        : (monthGrades.map((g) => g.value).reduce((a, b) => a + b) /
                  monthGrades.length)
              .toStringAsFixed(1);

    final gradesByStudentAndDate = <int, Map<String, Grade>>{};
    for (final grade in subjectGrades) {
      gradesByStudentAndDate.putIfAbsent(
        grade.studentId,
        () => {},
      )[_dateKey(grade.gradeDate)] = grade;
    }

    return AppShell(
      title: widget.className,
      child: RefreshIndicator(
        onRefresh: () =>
            context.read<JournalProvider>().loadForClass(widget.classId),
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
                              label: l10n.students,
                              value: roster.length.toString(),
                              icon: Icons.groups_outlined,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MetricCard(
                              label: l10n.grades,
                              value: monthGrades.length.toString(),
                              icon: Icons.edit_note_outlined,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MetricCard(
                              label: l10n.average,
                              value: averageLabel,
                              icon: Icons.insights_outlined,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final subject in subjects)
                          ChoiceChip(
                            label: Text(subject),
                            selected: subject == effectiveSubject,
                            onSelected: (_) =>
                                setState(() => _selectedSubject = subject),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.lgRadius,
                        border: Border.all(color: AppColors.border),
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
                  if (roster.isEmpty)
                    Expanded(
                      child: EmptyState(
                        icon: Icons.groups_outlined,
                        title: l10n.noStudents,
                        message: l10n.studentsAssignedWillAppear,
                      ),
                    )
                  else
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final totalGridWidth =
                              dateColumns.length * _kDateColumnWidth;
                          final availableGridWidth =
                              (constraints.maxWidth - _kNameColumnWidth - 48)
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
                                color: AppColors.surface,
                                borderRadius: AppRadius.lgRadius,
                                border: Border.all(color: AppColors.border),
                                boxShadow: AppShadows.card,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: _kNameColumnWidth,
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
                                              l10n.journalStudentColumn,
                                              style: theme.textTheme.labelLarge
                                                  ?.copyWith(
                                                    color: AppColors.primary,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        for (final entry
                                            in roster.asMap().entries)
                                          Container(
                                            height: _kRowHeight,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: entry.key.isOdd
                                                  ? AppColors.surfaceAlt
                                                  : AppColors.surface,
                                              border: const Border(
                                                top: BorderSide(
                                                  color: AppColors.border,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 28,
                                                  height: 28,
                                                  decoration: BoxDecoration(
                                                    gradient: AppGradients.tint(
                                                      AppColors.primary,
                                                    ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    entry
                                                            .value
                                                            .firstName
                                                            .isEmpty
                                                        ? '?'
                                                        : entry
                                                              .value
                                                              .firstName[0]
                                                              .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    entry.value.fullName,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                ),
                                              ],
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
                                                        .textTheme
                                                        .labelMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              date == today
                                                              ? FontWeight.bold
                                                              : FontWeight.w600,
                                                          color: date == today
                                                              ? AppColors
                                                                    .primary
                                                              : _isWeekend(date)
                                                              ? AppColors
                                                                    .textMuted
                                                              : AppColors
                                                                    .textSecondary,
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          for (final entry
                                              in roster.asMap().entries)
                                            Row(
                                              children: [
                                                for (final date in dateColumns)
                                                  _ReadOnlyGradeCell(
                                                    grade:
                                                        gradesByStudentAndDate[entry
                                                            .value
                                                            .id]?[_dateKey(
                                                          date,
                                                        )],
                                                    isWeekend: _isWeekend(date),
                                                    zebra: entry.key.isOdd,
                                                    onTap: (grade) =>
                                                        _showGradeDetails(
                                                          entry.value.fullName,
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
            ? AppColors.primary.withOpacity(0.08)
            : isWeekend
            ? AppColors.surfaceAlt
            : AppColors.primary.withOpacity(0.03),
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1.5),
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
        ? AppColors.surfaceAlt
        : zebra
        ? AppColors.surfaceAlt.withOpacity(0.6)
        : AppColors.surface;

    final grade = this.grade;

    final cell = Center(
      child: grade == null
          ? null
          : Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _gradeColor(grade.value).withOpacity(0.15),
                borderRadius: AppRadius.smRadius,
              ),
              alignment: Alignment.center,
              child: Text(
                grade.value.toString(),
                style: TextStyle(
                  color: _gradeColor(grade.value),
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
        border: const Border(top: BorderSide(color: AppColors.border)),
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
