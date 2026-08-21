import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../models/lesson_schedule.dart';
import '../services/diary_service.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/diary/diary_widgets.dart';
import '../widgets/empty_state.dart';

/// A parent's read-only view of their child's diary -- via the Public
/// Server only. Same premium day-navigator + lesson-card presentation as
/// [ClassDiaryScreen], just without the edit affordance.
class StudentDiaryScreen extends StatefulWidget {
  const StudentDiaryScreen({super.key, required this.studentId, required this.studentName});

  final int studentId;
  final String studentName;

  @override
  State<StudentDiaryScreen> createState() => _StudentDiaryScreenState();
}

class _StudentDiaryScreenState extends State<StudentDiaryScreen> {
  DateTime _selectedDate = DateTime.now();
  List<DiaryEntry>? _entries;
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
      final entries = await context.read<DiaryService>().fetchStudentDiary(widget.studentId, _selectedDate);
      if (mounted) setState(() => _entries = entries);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shiftDay(int deltaDays) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: deltaDays)));
    _load();
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
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = _entries;

    return AppShell(
      // A parent switching between children needs to see which one's diary
      // is on screen -- studentName was being passed in and never shown.
      title: widget.studentName.isEmpty ? l10n.ruznoma : '${l10n.ruznoma} · ${widget.studentName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: DiaryDayNavigator(
              date: _selectedDate,
              entryCount: entries?.length ?? 0,
              entries: entries ?? const [],
              onPrevious: () => _shiftDay(-1),
              onNext: () => _shiftDay(1),
              onPickDate: _pickDate,
            ),
          ),
          Expanded(
            child: _loading
                ? const AppLoadingIndicator()
                : _error != null
                    ? Center(child: Text(l10n.errorPrefix(_error!)))
                    : entries == null || entries.isEmpty
                        ? EmptyState(icon: Icons.menu_book_outlined, title: l10n.noDataTitle, message: l10n.noLessonsToday)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
                              children: [DiaryDayPage(entries: entries)],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
