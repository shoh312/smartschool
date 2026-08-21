import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../models/app_role.dart';
import '../models/lesson_schedule.dart';
import '../models/student.dart';
import '../providers/auth_provider.dart';
import '../providers/school_provider.dart';
import '../services/diary_service.dart';
import '../services/student_service.dart';
import '../services/teacher_service.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/diary/diary_widgets.dart';
import '../widgets/empty_state.dart';

class _ClassOption {
  const _ClassOption(this.id, this.name);
  final int id;
  final String name;
}

/// A class's resolved diary (today's/tomorrow's lessons -- subject, teacher,
/// room, homework, teacher's note) for director/teacher. Editable inline by
/// the lesson's assigned teacher, or the director as an override.
class ClassDiaryScreen extends StatefulWidget {
  const ClassDiaryScreen({super.key});

  @override
  State<ClassDiaryScreen> createState() => _ClassDiaryScreenState();
}

class _ClassDiaryScreenState extends State<ClassDiaryScreen> {
  List<_ClassOption> _classOptions = [];
  int? _selectedClassId;
  DateTime _selectedDate = DateTime.now();
  List<DiaryEntry> _entries = [];
  bool _loadingClasses = true;
  bool _loadingDiary = false;
  String? _error;

  /// A diary belongs to a pupil, so staff can narrow the class view down to
  /// one of them; null means "whole class" -- lessons and homework only,
  /// with no grade column, since a class has no single grade per lesson.
  List<Student> _roster = [];
  int? _selectedStudentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClasses());
  }

  Future<void> _loadClasses() async {
    final role = context.read<AuthProvider>().role;
    List<_ClassOption> options;
    if (role == AppRole.teacher) {
      final assignments = await context.read<TeacherService>().myClasses();
      final seen = <int>{};
      options = [
        for (final a in assignments)
          if (seen.add(a.classId)) _ClassOption(a.classId, a.className ?? ''),
      ];
    } else {
      final schoolProvider = context.read<SchoolProvider>();
      if (schoolProvider.classes.isEmpty) {
        await schoolProvider.loadSchoolData();
      }
      options = context.read<SchoolProvider>().classes.map((c) => _ClassOption(c.id, c.name)).toList();
    }

    if (!mounted) return;
    setState(() {
      _classOptions = options;
      _selectedClassId = options.isNotEmpty ? options.first.id : null;
      _loadingClasses = false;
    });
    if (_selectedClassId != null) {
      _loadRoster(); // loads the diary itself once a pupil is picked
    }
  }

  /// Teachers can only read their own classes' rosters (that endpoint is
  /// teacher-scoped); a director reads the school-wide student list and
  /// filters it down instead.
  Future<void> _loadRoster() async {
    final classId = _selectedClassId;
    if (classId == null) return;
    // Resolved up front: reaching for them through `context` after the
    // await would break if this screen is popped mid-request.
    final role = context.read<AuthProvider>().role;
    final teacherService = context.read<TeacherService>();
    final studentService = context.read<StudentService>();
    try {
      final students = role == AppRole.teacher
          ? await teacherService.classRoster(classId)
          : (await studentService.fetchStudents())
              .where((student) => student.classId == classId)
              .toList();
      if (!mounted) return;
      // A diary belongs to a pupil, so open on one instead of the class-wide
      // view: with nobody selected the page shows only homework and no
      // grades, which reads as "the grades are missing".
      setState(() {
        _roster = students;
        if (_selectedStudentId == null && students.isNotEmpty) {
          _selectedStudentId = students.first.id;
        }
      });
    } catch (_) {
      // A roster we can't load just means no per-student chips -- the
      // class-wide diary below still works, so this isn't worth an error
      // banner over the whole screen.
      if (mounted) setState(() => _roster = []);
    }
    // Loaded here rather than by the caller so the request always carries the
    // pupil picked just above -- firing both in parallel raced, and the
    // class-wide response could land last and blank the grades.
    if (mounted) await _loadDiary();
  }

  Future<void> _loadDiary() async {
    if (_selectedClassId == null) return;
    setState(() {
      _loadingDiary = true;
      _error = null;
    });
    try {
      final entries = await context.read<DiaryService>().fetchClassDiary(
            _selectedClassId!,
            _selectedDate,
            studentId: _selectedStudentId,
          );
      if (mounted) setState(() => _entries = entries);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingDiary = false);
    }
  }

  void _shiftDay(int deltaDays) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: deltaDays)));
    _loadDiary();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    _loadDiary();
  }

  Future<void> _editEntry(DiaryEntry entry) async {
    final result = await showDialog<(String?, String?)>(
      context: context,
      builder: (context) => _DiaryLogDialog(entry: entry),
    );
    if (result == null) return;

    final l10n = AppLocalizations.of(context)!;
    try {
      final updated = await context.read<DiaryService>().updateDiaryLog(
            entry.lessonId,
            _selectedDate,
            homework: result.$1,
            teacherComment: result.$2,
          );
      setState(() {
        final index = _entries.indexWhere((e) => e.lessonId == entry.lessonId);
        if (index != -1) _entries[index] = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorPrefix(e.toString()))));
      }
    }
  }

  /// Only the teacher this lesson is assigned to. A director can browse any
  /// class's diary but not write in it -- homework and the teacher's note
  /// are that teacher's own record, and the backend rejects anyone else.
  bool _canEdit(DiaryEntry entry) {
    final auth = context.read<AuthProvider>();
    return auth.role == AppRole.teacher && entry.teacherId == auth.teacherId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Whose diary this is has to be on screen: with one class the picker
    // chips are hidden entirely, so without this the page gave no clue
    // which class you were looking at.
    final selectedClassName = _classOptions
        .where((option) => option.id == _selectedClassId)
        .map((option) => option.name)
        .firstOrNull;
    final selectedStudentName = _roster
        .where((student) => student.id == _selectedStudentId)
        .map((student) => student.fullName)
        .firstOrNull;
    final owner = selectedStudentName ?? selectedClassName;

    return AppShell(
      title: owner == null || owner.isEmpty ? l10n.ruznoma : '${l10n.ruznoma} · $owner',
      child: _loadingClasses
          ? const AppLoadingIndicator()
          : _classOptions.isEmpty
              ? EmptyState(icon: Icons.menu_book_outlined, title: l10n.noDataTitle, message: l10n.noClasses)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: DiaryDayNavigator(
                        date: _selectedDate,
                        entryCount: _entries.length,
                        entries: _entries,
                        onPrevious: () => _shiftDay(-1),
                        onNext: () => _shiftDay(1),
                        onPickDate: _pickDate,
                      ),
                    ),
                    if (_classOptions.length > 1)
                      SizedBox(
                        height: 46,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                          itemCount: _classOptions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final option = _classOptions[index];
                            final selected = option.id == _selectedClassId;
                            return ChoiceChip(
                              label: Text(option.name),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedClassId = option.id;
                                  // Last class's pupil can't stay selected.
                                  _selectedStudentId = null;
                                  _roster = [];
                                });
                                _loadRoster();
                              },
                            );
                          },
                        ),
                      ),
                    if (_roster.isNotEmpty)
                      SizedBox(
                        height: 46,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                          itemCount: _roster.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final student = _roster[index];
                            final selected = student.id == _selectedStudentId;
                            return ChoiceChip(
                              label: Text(student.fullName),
                              selected: selected,
                              // No separate "whole class" chip: deselecting the
                              // current pupil is what returns you to the
                              // class-wide diary.
                              onSelected: (_) {
                                setState(() => _selectedStudentId = selected ? null : student.id);
                                _loadDiary();
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _loadingDiary
                          ? const AppLoadingIndicator()
                          : _error != null
                              ? Center(child: Text(l10n.errorPrefix(_error!)))
                              : _entries.isEmpty
                                  ? EmptyState(
                                      icon: Icons.menu_book_outlined,
                                      title: l10n.noDataTitle,
                                      message: l10n.noLessonsToday,
                                    )
                                  : RefreshIndicator(
                                      onRefresh: _loadDiary,
                                      child: ListView(
                                        padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
                                        children: [
                                          DiaryDayPage(
                                            entries: _entries,
                                            canEdit: _canEdit,
                                            onTapEntry: _editEntry,
                                          ),
                                        ],
                                      ),
                                    ),
                    ),
                  ],
                ),
    );
  }
}

class _DiaryLogDialog extends StatefulWidget {
  const _DiaryLogDialog({required this.entry});

  final DiaryEntry entry;

  @override
  State<_DiaryLogDialog> createState() => _DiaryLogDialogState();
}

class _DiaryLogDialogState extends State<_DiaryLogDialog> {
  late final TextEditingController _homeworkController;
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _homeworkController = TextEditingController(text: widget.entry.homework ?? '');
    _commentController = TextEditingController(text: widget.entry.teacherComment ?? '');
  }

  @override
  void dispose() {
    _homeworkController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.entry.subject),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _homeworkController,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.homeworkLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(labelText: l10n.teacherNoteLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, (_homeworkController.text.trim(), _commentController.text.trim())),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
