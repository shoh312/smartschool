import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/class_subject_assignment.dart';
import '../models/lesson_schedule.dart';
import '../models/school_class.dart';
import '../services/lesson_service.dart';
import '../services/teacher_service.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/empty_state.dart';

/// A director's weekly Lesson-schedule editor for one class -- the source
/// of truth the camera-attendance system and the electronic diary both read
/// from. Distinct from the older `Class.timetable` JSON blob edited on
/// [ClassManagementScreen] (subject + duration only): this is per-lesson,
/// with a real start time, an assigned teacher, and a room.
class LessonScheduleScreen extends StatefulWidget {
  const LessonScheduleScreen({super.key, required this.schoolClass});

  final SchoolClass schoolClass;

  @override
  State<LessonScheduleScreen> createState() => _LessonScheduleScreenState();
}

class _LessonScheduleScreenState extends State<LessonScheduleScreen> {
  static const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

  String _selectedDay = 'mon';
  Map<String, List<LessonSlot>> _lessonsByDay = {for (final d in _dayKeys) d: []};
  List<ClassSubjectAssignment> _assignments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lessonService = context.read<LessonService>();
      final teacherService = context.read<TeacherService>();
      final lessons = await lessonService.fetchLessons(widget.schoolClass.id);
      final assignments = await teacherService.classSubjects(widget.schoolClass.id);

      final grouped = {for (final d in _dayKeys) d: <LessonSlot>[]};
      for (final lesson in lessons) {
        final index = lesson.dayOfWeek.clamp(0, _dayKeys.length - 1);
        grouped[_dayKeys[index]]!.add(lesson);
      }
      for (final list in grouped.values) {
        list.sort((a, b) => a.startTime.compareTo(b.startTime));
      }

      if (!mounted) return;
      setState(() {
        _lessonsByDay = grouped;
        _assignments = assignments;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({LessonSlot? existing}) async {
    final result = await showDialog<_LessonFormResult>(
      context: context,
      builder: (context) => _LessonFormDialog(
        assignments: _assignments,
        existing: existing,
      ),
    );
    if (result == null) return;

    final l10n = AppLocalizations.of(context)!;
    final dayIndex = _dayKeys.indexOf(_selectedDay);
    final lessonService = context.read<LessonService>();

    try {
      if (existing == null) {
        final created = await lessonService.createLesson(LessonSlot(
          id: 0,
          classId: widget.schoolClass.id,
          subject: result.subject,
          dayOfWeek: dayIndex,
          startTime: result.startTime,
          durationMinutes: result.durationMinutes,
          teacherId: result.teacherId,
          room: result.room,
        ));
        setState(() => _lessonsByDay[_selectedDay] = [..._lessonsByDay[_selectedDay]!, created]
          ..sort((a, b) => a.startTime.compareTo(b.startTime)));
      } else {
        final updated = await lessonService.updateLesson(existing.id, LessonSlot(
          id: existing.id,
          classId: widget.schoolClass.id,
          subject: result.subject,
          dayOfWeek: dayIndex,
          startTime: result.startTime,
          durationMinutes: result.durationMinutes,
          teacherId: result.teacherId,
          room: result.room,
        ));
        setState(() {
          final list = _lessonsByDay[_selectedDay]!;
          final index = list.indexWhere((l) => l.id == existing.id);
          if (index != -1) list[index] = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorPrefix(e.toString()))));
      }
    }
  }

  Future<void> _delete(LessonSlot lesson) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteLessonTitle),
        content: Text(l10n.deleteLessonConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await context.read<LessonService>().deleteLesson(lesson.id);
      setState(() => _lessonsByDay[_selectedDay]!.removeWhere((l) => l.id == lesson.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorPrefix(e.toString()))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayLabels = [l10n.weekday1, l10n.weekday2, l10n.weekday3, l10n.weekday4, l10n.weekday5, l10n.weekday6];
    final currentLessons = _lessonsByDay[_selectedDay] ?? [];

    return AppShell(
      title: l10n.lessonSchedule(widget.schoolClass.name),
      child: _loading
          ? const AppLoadingIndicator()
          : _error != null
              ? Center(child: Text(l10n.errorPrefix(_error!)))
              : ListView(
                  padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < _dayKeys.length; i++)
                            Padding(
                              padding: EdgeInsets.only(right: i < _dayKeys.length - 1 ? 6 : 0),
                              child: FilterChip(
                                label: Text(dayLabels[i]),
                                selected: _selectedDay == _dayKeys[i],
                                onSelected: (_) => setState(() => _selectedDay = _dayKeys[i]),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (currentLessons.isEmpty)
                      SizedBox(
                        height: 160,
                        child: EmptyState(
                          icon: Icons.schedule_outlined,
                          title: l10n.noLessonsForDay,
                          message: l10n.addLesson,
                        ),
                      )
                    else
                      ...currentLessons.map((lesson) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppListCard(
                              leading: AppListBadge(text: lesson.startTime),
                              title: lesson.subject,
                              subtitle: [
                                if (lesson.teacherName != null) lesson.teacherName!,
                                if (lesson.room != null) lesson.room!,
                                '${lesson.durationMinutes} ${l10n.minutesUnit}',
                              ].join(' • '),
                              onTap: () => _openEditor(existing: lesson),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline, size: 20, color: context.colors.danger),
                                onPressed: () => _delete(lesson),
                              ),
                            ),
                          )),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.addLesson),
                    ),
                  ],
                ),
    );
  }
}

class _LessonFormResult {
  const _LessonFormResult({
    required this.subject,
    required this.startTime,
    required this.durationMinutes,
    this.teacherId,
    this.room,
  });

  final String subject;
  final String startTime;
  final int durationMinutes;
  final int? teacherId;
  final String? room;
}

class _LessonFormDialog extends StatefulWidget {
  const _LessonFormDialog({required this.assignments, this.existing});

  final List<ClassSubjectAssignment> assignments;
  final LessonSlot? existing;

  @override
  State<_LessonFormDialog> createState() => _LessonFormDialogState();
}

class _LessonFormDialogState extends State<_LessonFormDialog> {
  late final TextEditingController _startTimeController;
  late final TextEditingController _durationController;
  late final TextEditingController _roomController;
  ClassSubjectAssignment? _selectedAssignment;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _startTimeController = TextEditingController(text: existing?.startTime ?? '');
    _durationController = TextEditingController(text: (existing?.durationMinutes ?? 45).toString());
    _roomController = TextEditingController(text: existing?.room ?? '');
    if (existing != null) {
      for (final a in widget.assignments) {
        if (a.teacherId == existing.teacherId && a.subject == existing.subject) {
          _selectedAssignment = a;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _durationController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(widget.existing == null ? l10n.addLesson : l10n.editLesson),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<ClassSubjectAssignment>(
              value: _selectedAssignment,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.subjectLabel),
              items: widget.assignments
                  .map((a) => DropdownMenuItem(
                        value: a,
                        child: Text('${a.subject ?? ''} — ${a.teacherName}', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedAssignment = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _startTimeController,
              decoration: const InputDecoration(labelText: 'HH:MM', hintText: '08:00'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.minutesUnit),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roomController,
              decoration: InputDecoration(labelText: l10n.roomLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: _selectedAssignment == null || _startTimeController.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    _LessonFormResult(
                      subject: _selectedAssignment!.subject ?? '',
                      startTime: _startTimeController.text.trim(),
                      durationMinutes: int.tryParse(_durationController.text.trim()) ?? 45,
                      teacherId: _selectedAssignment!.teacherId,
                      room: _roomController.text.trim().isEmpty ? null : _roomController.text.trim(),
                    ),
                  ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
