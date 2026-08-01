import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../models/school_class.dart';
import '../providers/school_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import 'class_subjects_screen.dart';

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

  final _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  String _selectedDay = 'mon';

  Map<String, List<_LessonData>> _timetable = {};

  @override
  void initState() {
    super.initState();
    _resetTimetable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SchoolProvider>().loadSchoolData();
    });
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteClassTitle),
        content: Text(l10n.deleteClassConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.delete,
              style: TextStyle(color: context.colors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
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
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _editingClass == null
                        ? l10n.createNewClass
                        : l10n.editClass,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: _startTimeController,
                    decoration: InputDecoration(
                      labelText: l10n.startTime,
                      hintText: 'HH:MM',
                    ),
                  ),
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
          ),
          const SizedBox(height: 28),
          Text(
            l10n.existingClasses,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
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
            ...provider.classes.map(
              (schoolClass) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: AppRadius.lgRadius,
                  border: Border.all(color: context.colors.border),
                  boxShadow: AppShadows.card,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.lgRadius,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ClassSubjectsScreen(schoolClass: schoolClass),
                    ),
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppGradients.accent,
                      borderRadius: AppRadius.mdRadius,
                      boxShadow: AppShadows.colored(context.colors.accent),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      schoolClass.grade.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    schoolClass.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(l10n.gradeLabel(schoolClass.grade.toString())),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
            ),
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
