import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../models/school_class.dart';
import '../providers/school_provider.dart';
import '../services/school_service.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/collapsible_form_card.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/empty_state.dart';
import 'class_journal_screen.dart';
import 'class_subjects_screen.dart';
import 'lesson_schedule_screen.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key, this.isIntegrated = false});
  final bool isIntegrated;
  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _detectController = TextEditingController(text: '10');
  final _waitController = TextEditingController(text: '20');
  SchoolClass? _editingClass;
  bool _formOpen = false;

  final _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  String _selectedDay = 'mon';

  Map<String, List<_LessonData>> _timetable = {};

  /// An academy keeps its schedule on the camera, not on the class.
  bool _groupMode = false;

  @override
  void initState() {
    super.initState();
    _resetTimetable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SchoolProvider>().loadSchoolData();
      _loadGroupMode();
    });
  }

  Future<void> _loadGroupMode() async {
    try {
      final settings = await context.read<SchoolService>().fetchSettings();
      if (mounted) setState(() => _groupMode = settings.groupMode);
    } catch (_) {
      // Left off, which is the ordinary school layout.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _startTimeController.dispose();
    _detectController.dispose();
    _waitController.dispose();
    super.dispose();
  }

  void _resetTimetable() {
    _timetable = {for (final d in _dayKeys) d: <_LessonData>[]};
  }

  void _prepareEdit(SchoolClass schoolClass) {
    setState(() {
      // Editing opens the form itself: the user tapped a pencil on a row,
      // not the "+" header.
      _formOpen = true;
      _editingClass = schoolClass;
      _nameController.text = schoolClass.name;
      _gradeController.text = schoolClass.grade.toString();
      _startTimeController.text = schoolClass.startTime ?? '';
      _detectController.text = (schoolClass.detectDurationSeconds ?? 10)
          .toString();
      _waitController.text = (schoolClass.waitDurationMinutes ?? 20).toString();
      _timetable = {for (final d in _dayKeys) d: <_LessonData>[]};
      for (final d in _dayKeys) {
        final entries = schoolClass.timetable[d];
        if (entries != null) {
          _timetable[d] = entries
              .map((e) => _LessonData(e.subject, e.durationMinutes))
              .toList();
        }
      }
    });
  }

  void _clear() {
    setState(() {
      _formOpen = false;
      _editingClass = null;
      _nameController.clear();
      _gradeController.clear();
      _startTimeController.clear();
      _detectController.text = '10';
      _waitController.text = '20';
      _resetTimetable();
      _selectedDay = 'mon';
    });
  }

  Future<void> _save() async {
    final grade =
        int.tryParse(_gradeController.text.trim()) ??
        int.tryParse(
          _nameController.text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;

    final tt = <String, List<TimetableEntry>>{};
    for (final d in _dayKeys) {
      final entries = _timetable[d] ?? [];
      if (entries.isEmpty) continue;
      tt[d] = entries
          .map(
            (e) => TimetableEntry(
              subject: e.subject,
              durationMinutes: e.durationMinutes,
            ),
          )
          .toList();
    }

    final schoolClass = SchoolClass(
      id: _editingClass?.id ?? 0,
      name: _nameController.text.trim().toUpperCase(),
      grade: grade,
      startTime: _startTimeController.text.trim().isEmpty
          ? null
          : _startTimeController.text.trim(),
      endTime: null,
      detectDurationSeconds: int.tryParse(_detectController.text.trim()),
      waitDurationMinutes: int.tryParse(_waitController.text.trim()),
      timetable: tt,
    );

    if (_editingClass == null) {
      await context.read<SchoolProvider>().createClass(schoolClass);
    } else {
      await context.read<SchoolProvider>().updateClass(schoolClass);
    }
    _clear();
  }

  Future<void> _delete(int id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showAppConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: l10n.deleteClassTitle,
      message: l10n.deleteClassConfirm,
      isDestructive: true,
    );
    if (confirm && mounted) {
      await context.read<SchoolProvider>().deleteClass(id);
    }
  }

  void _addLesson() {
    setState(() {
      _timetable[_selectedDay]!.add(_LessonData('', 45));
    });
  }

  void _removeLesson(int index) {
    setState(() {
      _timetable[_selectedDay]!.removeAt(index);
    });
  }

  double _dayHours(String day) {
    final entries = _timetable[day] ?? [];
    return entries.fold(0.0, (sum, e) => sum + e.durationMinutes) / 60;
  }

  double _totalHours() {
    double total = 0;
    for (final d in _dayKeys) {
      total += _dayHours(d);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SchoolProvider>();
    final l10n = AppLocalizations.of(context)!;
    final currentLessons = _timetable[_selectedDay] ?? [];

    return AppShell(
      title: l10n.classManagement,
      showAppBar: !widget.isIntegrated,
      child: ListView(
        padding: (const EdgeInsets.fromLTRB(16, 16, 16, 24)).add(bottomNavPadding(context)),
        children: [
          CollapsibleFormCard(
            title: _editingClass == null ? l10n.createNewClass : l10n.editClass,
            expanded: _formOpen,
            onToggle: () {
              if (_formOpen) {
                _clear();
              } else {
                setState(() => _formOpen = true);
              }
            },
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: l10n.classNameLabel,
                      hintText: l10n.classNameHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _gradeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.gradeOptional,
                      hintText: l10n.gradeHint,
                    ),
                  ),
                  // Hidden in group mode: the backend never reads a
                  // group's start_time/timetable off the Class (see
                  // live_detection.py's "the slot is the window here").
                  // An academy group's actual hours come from the camera
                  // position slot it's assigned when the camera is set
                  // up, same reasoning as hiding the lesson-schedule icon
                  // below.
                  if (!_groupMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _startTimeController,
                      decoration: InputDecoration(
                        labelText: l10n.startTime,
                        hintText: 'HH:MM',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _detectController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.detectSec,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _waitController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.waitMin,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Same reasoning as the start-time field above: an
                  // academy's per-day subject list is never read by the
                  // backend for a group-mode class (only the camera
                  // position slot is), so building one here would just be
                  // a second, unused place to enter a schedule.
                  if (!_groupMode) ...[
                    const SizedBox(height: 20),
                    Text(
                      l10n.timetableLabel,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.totalHoursPerWeek(_totalHours().toStringAsFixed(1)),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          l10n.weekday1,
                          l10n.weekday2,
                          l10n.weekday3,
                          l10n.weekday4,
                          l10n.weekday5,
                          l10n.weekday6,
                        ].asMap().entries.map((dayLabelEntry) {
                          final i = dayLabelEntry.key;
                          final dayLabel = dayLabelEntry.value;
                          final d = _dayKeys[i];
                          final hours = _dayHours(d);
                          final selected = _selectedDay == d;
                          return Padding(
                            padding: EdgeInsets.only(
                              right: i < _dayKeys.length - 1 ? 6 : 0,
                            ),
                            child: FilterChip(
                              label: Text(
                                '$dayLabel${hours > 0 ? " ${hours.toStringAsFixed(1)}h" : ""}',
                              ),
                              selected: selected,
                              onSelected: (_) => setState(() => _selectedDay = d),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (currentLessons.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            l10n.noLessonsForDay,
                            style: TextStyle(color: context.colors.textMuted),
                          ),
                        ),
                      )
                    else
                      ...currentLessons.asMap().entries.map((entry) {
                        final i = entry.key;
                        final lesson = entry.value;
                        return _LessonRow(
                          key: ValueKey('${_selectedDay}_$i'),
                          lesson: lesson,
                          onRemove: () => _removeLesson(i),
                        );
                      }),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: _addLesson,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.addLesson),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_editingClass != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _clear,
                            child: Text(l10n.cancel),
                          ),
                        ),
                      if (_editingClass != null) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _save,
                          icon: Icon(
                            _editingClass == null ? Icons.add : Icons.save,
                          ),
                          label: Text(
                            _editingClass == null
                                ? l10n.createClass
                                : l10n.saveChanges,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ),
          const SizedBox(height: 26),
          DashboardSectionHeader(title: l10n.existingClasses),
          if (provider.classes.isEmpty)
            SizedBox(
              height: 200,
              child: EmptyState(
                icon: Icons.class_outlined,
                title: l10n.noClasses,
                message: l10n.createClassesMessage,
              ),
            )
          else
            ...provider.classes.asMap().entries.map((entry) {
              final index = entry.key;
              final schoolClass = entry.value;
              return FadeSlideIn(
                delay: index < 12 ? Duration(milliseconds: 40 * index) : Duration.zero,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppListCard(
                    leading: AppListBadge(text: schoolClass.grade.toString()),
                    title: schoolClass.name,
                    subtitle: l10n.gradeLabel(schoolClass.grade.toString()),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ClassSubjectsScreen(schoolClass: schoolClass),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The journal used to be reachable only as an icon
                        // buried in this class's subjects screen (or from a
                        // duplicate dashboard tile). One tap from the class
                        // row is where staff actually look for it.
                        IconButton(
                          tooltip: l10n.viewJournal,
                          icon: Icon(
                            Icons.menu_book_outlined,
                            size: 20,
                            color: context.colors.textMuted,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClassJournalScreen(
                                classId: schoolClass.id,
                                className: schoolClass.name,
                              ),
                            ),
                          ),
                        ),
                        // Hidden in group mode, where the schedule is
                        // the camera's list of groups instead: an
                        // academy has no lesson timetable to keep, and
                        // two places to enter one is what made this
                        // confusing. Schools that give every class its
                        // own room still need it -- the diary, the
                        // subject register and per-lesson absence all
                        // read from it.
                        if (!_groupMode)
                          IconButton(
                            tooltip: l10n.lessonSchedule(schoolClass.name),
                            icon: Icon(
                              Icons.schedule_outlined,
                              size: 20,
                              color: context.colors.textMuted,
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LessonScheduleScreen(schoolClass: schoolClass),
                              ),
                            ),
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: context.colors.textMuted,
                          ),
                          onPressed: () => _prepareEdit(schoolClass),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: context.colors.danger,
                          ),
                          onPressed: () => _delete(schoolClass.id),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _LessonData {
  String subject;
  int durationMinutes;
  _LessonData(this.subject, this.durationMinutes);
}

class _LessonRow extends StatefulWidget {
  const _LessonRow({super.key, required this.lesson, required this.onRemove});
  final _LessonData lesson;
  final VoidCallback onRemove;

  @override
  State<_LessonRow> createState() => _LessonRowState();
}

class _LessonRowState extends State<_LessonRow> {
  late TextEditingController _durationCtrl;

  @override
  void initState() {
    super.initState();
    _durationCtrl = TextEditingController(
      text: widget.lesson.durationMinutes.toString(),
    );
  }

  @override
  void didUpdateWidget(_LessonRow old) {
    super.didUpdateWidget(old);
    if (old.lesson != widget.lesson) {
      _durationCtrl.text = widget.lesson.durationMinutes.toString();
    }
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lesson = widget.lesson;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: AppConstants.schoolSubjects.contains(lesson.subject)
                  ? lesson.subject
                  : null,
              isExpanded: true,
              hint: Text(l10n.subjectLabel),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.subjectLabel,
              ),
              items: AppConstants.schoolSubjects
                  .map(
                    (subject) => DropdownMenuItem(
                      value: subject,
                      child: Text(subject, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => lesson.subject = value);
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                labelText: l10n.minutesUnit,
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null && parsed > 0) {
                  lesson.durationMinutes = parsed;
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.remove_circle_outline,
              size: 20,
              color: context.colors.danger,
            ),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}
