import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/grade.dart';
import '../models/student.dart';
import '../providers/teacher_provider.dart';
import '../utils/date_formatters.dart';
import '../utils/error_formatter.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_card.dart';
import 'journal_scan_screen.dart';

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

Color _gradeColor(BuildContext context, int value) {
  if (value >= 9) return context.colors.success;
  if (value >= 7) return context.colors.info;
  if (value >= 5) return context.colors.warning;
  return context.colors.danger;
}

class ClassRosterScreen extends StatefulWidget {
  const ClassRosterScreen({
    super.key,
    required this.classId,
    required this.className,
    this.subject = '',
  });

  final int classId;
  final String className;
  final String subject;

  @override
  State<ClassRosterScreen> createState() => _ClassRosterScreenState();
}

class _ClassRosterScreenState extends State<ClassRosterScreen> {
  late DateTime _viewedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewedMonth = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherProvider>().loadRoster(widget.classId);
      context.read<TeacherProvider>().loadClassGrades(
        widget.classId,
        widget.subject,
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

  Future<void> _showGradeComment(Student student, Grade grade) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
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
                          student.fullName,
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

  Future<void> _openGradeDialog(
    Student student,
    DateTime date,
    Grade? existing,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    int value = existing?.value ?? 5;
    final commentController = TextEditingController(
      text: existing?.comment ?? '',
    );

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
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
                Text(
                  student.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  _dateKey(date),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.journalScoreLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var option = 1; option <= 10; option++)
                      _ScoreOption(
                        value: option,
                        selected: value == option,
                        onTap: () => setDialogState(() => value = option),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: commentController,
                  decoration: InputDecoration(
                    labelText: l10n.journalCommentOptional,
                    prefixIcon: const Icon(Icons.chat_bubble_outline, size: 20),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (existing != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context, 'delete'),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(l10n.delete),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colors.danger,
                            side: BorderSide(color: context.colors.danger),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.mdRadius,
                            ),
                          ),
                        ),
                      ),
                    if (existing != null) const SizedBox(width: 12),
                    Expanded(
                      flex: existing != null ? 1 : 1,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, 'save'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.mdRadius,
                          ),
                        ),
                        child: Text(l10n.save),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      if (action == null || !mounted) return;

      final teacherProvider = context.read<TeacherProvider>();
      bool success;
      if (action == 'delete' && existing != null) {
        success = await teacherProvider.deleteGrade(existing.id);
      } else if (existing != null) {
        success = await teacherProvider.updateGrade(
          gradeId: existing.id,
          value: value,
          comment: commentController.text.trim().isEmpty
              ? null
              : commentController.text.trim(),
        );
      } else {
        success = await teacherProvider.submitGrade(
          studentId: student.id,
          classId: widget.classId,
          subject: widget.subject,
          value: value,
          comment: commentController.text.trim().isEmpty
              ? null
              : commentController.text.trim(),
          gradeDate: date,
        );
      }

      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorPrefix(humanReadableError(teacherProvider.error, l10n))),
          ),
        );
      }
    } finally {
      commentController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final teacherProvider = context.watch<TeacherProvider>();
    final roster = teacherProvider.roster;
    final grades = teacherProvider.classGrades;
    final today = _dateOnly(DateTime.now());
    final theme = Theme.of(context);
    final monthLabel = DateFormatters.monthYear(l10n, _viewedMonth);

    final dateColumns = [
      for (var day = 1; day <= _daysInMonth(_viewedMonth); day++)
        DateTime(_viewedMonth.year, _viewedMonth.month, day),
    ];

    final monthGrades = grades.where((grade) {
      final date = _dateOnly(grade.gradeDate);
      return date.year == _viewedMonth.year && date.month == _viewedMonth.month;
    }).toList();
    final averageLabel = monthGrades.isEmpty
        ? '-'
        : (monthGrades.map((g) => g.value).reduce((a, b) => a + b) /
                  monthGrades.length)
              .toStringAsFixed(1);

    final gradesByStudentAndDate = <int, Map<String, Grade>>{};
    for (final grade in grades) {
      gradesByStudentAndDate.putIfAbsent(
        grade.studentId,
        () => {},
      )[_dateKey(grade.gradeDate)] = grade;
    }

    final isLoading =
        teacherProvider.isRosterLoading || teacherProvider.isJournalLoading;

    return AppShell(
      title: '${widget.className} • ${widget.subject}',
      actions: [
        IconButton(
          icon: const Icon(Icons.document_scanner_outlined),
          tooltip: l10n.journalScanTitle,
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => JournalScanScreen(
                  classId: widget.classId,
                  className: widget.className,
                  subject: widget.subject,
                ),
              ),
            );
            if (!mounted) return;
            context.read<TeacherProvider>().loadClassGrades(widget.classId, widget.subject);
          },
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          await context.read<TeacherProvider>().loadRoster(widget.classId);
          await context.read<TeacherProvider>().loadClassGrades(
            widget.classId,
            widget.subject,
          );
        },
        child: roster.isEmpty && !isLoading
            ? EmptyState(
                icon: Icons.groups_outlined,
                title: l10n.journalNoStudentsTitle,
                message: l10n.journalNoStudentsMessage,
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
                              icon: Icons.groups_2_outlined,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MetricCard(
                              label: l10n.grades,
                              value: monthGrades.length.toString(),
                              icon: Icons.grading_rounded,
                              color: context.colors.success,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MetricCard(
                              label: l10n.average,
                              value: averageLabel,
                              icon: Icons.trending_up_rounded,
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
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _changeMonth(-1),
                          ),
                          Expanded(
                            child: Text(
                              monthLabel,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _isCurrentMonth
                                ? null
                                : () => _changeMonth(1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isLoading && roster.isEmpty)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final totalGridWidth =
                              dateColumns.length * _kDateColumnWidth;
                          // 34 = 16px padding on each side of the scroll
                          // view, plus the 1px border on each side of the
                          // table's own container.
                          final availableGridWidth =
                              (constraints.maxWidth - _kNameColumnWidth - 34)
                                  .clamp(0.0, double.infinity);
                          final gridViewportWidth =
                              totalGridWidth < availableGridWidth
                              ? totalGridWidth
                              : availableGridWidth;
                          return SingleChildScrollView(
                            padding: (const EdgeInsets.fromLTRB(16, 0, 16, 16)).add(bottomNavPadding(context)),
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius: AppRadius.lgRadius,
                                border: Border.all(color: context.colors.border),
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
                                                    fontWeight: FontWeight.bold,
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
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
                                                  ? context.colors.surfaceAlt
                                                  : context.colors.surface,
                                              border: Border(
                                                top: BorderSide(
                                                  color: context.colors.border,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: theme
                                                      .colorScheme
                                                      .primary
                                                      .withOpacity(0.1),
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
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
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
                                                          color: context.colors
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
                                                  child: date == today
                                                      ? Container(
                                                          width: 26,
                                                          height: 26,
                                                          decoration:
                                                              BoxDecoration(
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                          alignment:
                                                              Alignment.center,
                                                          child: Text(
                                                            '${date.day}',
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        )
                                                      : Text(
                                                          '${date.day}',
                                                          style: theme
                                                              .textTheme
                                                              .labelMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    _isWeekend(
                                                                      date,
                                                                    )
                                                                    ? context.colors
                                                                          .textMuted
                                                                    : theme
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
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
                                                  _GradeCell(
                                                    grade:
                                                        gradesByStudentAndDate[entry
                                                            .value
                                                            .id]?[_dateKey(
                                                          date,
                                                        )],
                                                    enabled: date == today,
                                                    isWeekend: _isWeekend(date),
                                                    zebra: entry.key.isOdd,
                                                    onTap: () {
                                                      final existing =
                                                          gradesByStudentAndDate[entry
                                                              .value
                                                              .id]?[_dateKey(
                                                            date,
                                                          )];
                                                      if (date == today) {
                                                        _openGradeDialog(
                                                          entry.value,
                                                          date,
                                                          existing,
                                                        );
                                                      } else if (existing !=
                                                          null) {
                                                        _showGradeComment(
                                                          entry.value,
                                                          existing,
                                                        );
                                                      }
                                                    },
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
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      alignment: alignment,
      decoration: BoxDecoration(
        color: isToday
            ? theme.colorScheme.primary.withOpacity(0.08)
            : isWeekend
            ? context.colors.surfaceAlt
            : theme.colorScheme.primary.withOpacity(0.04),
        border: Border(
          bottom: BorderSide(color: context.colors.border, width: 1.5),
        ),
      ),
      child: child,
    );
  }
}

class _ScoreOption extends StatelessWidget {
  const _ScoreOption({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _gradeColor(context, value);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.25),
            width: selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          value.toString(),
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _GradeCell extends StatelessWidget {
  const _GradeCell({
    required this.grade,
    required this.enabled,
    required this.isWeekend,
    required this.zebra,
    required this.onTap,
  });

  final Grade? grade;
  final bool enabled;
  final bool isWeekend;
  final bool zebra;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = enabled
        ? Theme.of(context).colorScheme.primary.withOpacity(0.04)
        : isWeekend
        ? context.colors.surfaceAlt
        : zebra
        ? context.colors.surfaceAlt
        : context.colors.surface;

    final cellChild = Center(
      child: grade == null
          ? enabled
                ? Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.4),
                  )
                : null
          : Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _gradeColor(
                  context,
                  grade!.value,
                ).withOpacity(enabled ? 1 : 0.15),
                borderRadius: BorderRadius.circular(9),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: _gradeColor(context, grade!.value).withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                grade!.value.toString(),
                style: TextStyle(
                  color: enabled ? Colors.white : _gradeColor(context, grade!.value),
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
      child: (enabled || grade != null)
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(9),
              child: cellChild,
            )
          : cellChild,
    );
  }
}
