import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/lesson_schedule.dart';
import '../services/diary_service.dart';
import '../utils/date_formatters.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/empty_state.dart';

/// "Uy vazifalari" -- every upcoming/recent homework entry across several
/// days (not just one day's diary), grouped by date. Reads the same
/// DiaryEntry data as the single-day Ruznoma, just spread over a range.
class HomeworkListScreen extends StatefulWidget {
  const HomeworkListScreen({super.key, required this.studentId, required this.studentName});

  final int studentId;
  final String studentName;

  @override
  State<HomeworkListScreen> createState() => _HomeworkListScreenState();
}

class _HomeworkListScreenState extends State<HomeworkListScreen> {
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
      final entries = await context.read<DiaryService>().fetchHomework(widget.studentId);
      if (mounted) setState(() => _entries = entries);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<DateTime, List<DiaryEntry>> _groupByDate(List<DiaryEntry> entries) {
    final groups = <DateTime, List<DiaryEntry>>{};
    for (final entry in entries) {
      final date = entry.logDate;
      if (date == null) continue;
      final key = DateTime(date.year, date.month, date.day);
      groups.putIfAbsent(key, () => []).add(entry);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = _entries;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    return AppShell(
      title: l10n.homeworkListTitle,
      child: _loading
          ? const AppLoadingIndicator()
          : _error != null
              ? Center(child: Text(l10n.errorPrefix(_error!)))
              : entries == null || entries.isEmpty
                  ? EmptyState(icon: Icons.assignment_outlined, title: l10n.noDataTitle, message: l10n.noHomeworkMessage)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: Builder(builder: (context) {
                        final groups = _groupByDate(entries);
                        final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
                        return ListView(
                          padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
                          children: [
                            for (final date in dates) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                                child: Row(
                                  children: [
                                    Text(
                                      date == todayKey ? l10n.todayLessons : DateFormatters.weekdayShort(l10n, date.weekday),
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormatters.shortDate(date),
                                      style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              for (final entry in groups[date]!)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _HomeworkCard(entry: entry),
                                ),
                            ],
                          ],
                        );
                      }),
                    ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({required this.entry});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: AppGradients.tint(context.colors.primary), borderRadius: AppRadius.smRadius),
                child: Icon(Icons.assignment_outlined, color: context.colors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(entry.subject, style: Theme.of(context).textTheme.titleSmall),
              ),
              Text(
                entry.startTime,
                style: TextStyle(fontSize: 12, color: context.colors.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (entry.homework != null && entry.homework!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(entry.homework!, style: TextStyle(fontSize: 13.5, color: context.colors.textPrimary, height: 1.4)),
          ],
          if (entry.teacherName != null) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.teacherWord}: ${entry.teacherName}',
              style: TextStyle(fontSize: 11.5, color: context.colors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
