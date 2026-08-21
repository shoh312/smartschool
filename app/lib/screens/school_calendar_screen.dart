import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/app_role.dart';
import '../models/school_event.dart';
import '../providers/auth_provider.dart';
import '../services/calendar_service.dart';
import '../utils/date_formatters.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/empty_state.dart';

/// The school calendar: holidays, exams, control-work days, and events.
/// Director/teacher see the whole school's list (director can add/delete);
/// a parent (via [studentId]) sees whole-school events plus their child's
/// class-specific ones, read-only, through the Public Server.
class SchoolCalendarScreen extends StatefulWidget {
  const SchoolCalendarScreen({super.key, this.studentId});

  /// Set only when opened from the parent flow.
  final int? studentId;

  @override
  State<SchoolCalendarScreen> createState() => _SchoolCalendarScreenState();
}

class _SchoolCalendarScreenState extends State<SchoolCalendarScreen> {
  List<SchoolEvent>? _events;
  bool _loading = true;
  String? _error;

  bool get _isParent => widget.studentId != null;

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
      final service = context.read<CalendarService>();
      final events = _isParent
          ? await service.fetchStudentEvents(widget.studentId!)
          : await service.fetchEvents();
      events.sort((a, b) => a.startDate.compareTo(b.startDate));
      if (mounted) setState(() => _events = events);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _colorFor(BuildContext context, SchoolEventType type) {
    switch (type) {
      case SchoolEventType.holiday:
        return context.colors.success;
      case SchoolEventType.exam:
        return context.colors.danger;
      case SchoolEventType.test:
        return context.colors.warning;
      case SchoolEventType.event:
        return context.colors.primary;
    }
  }

  String _labelFor(AppLocalizations l10n, SchoolEventType type) {
    switch (type) {
      case SchoolEventType.holiday:
        return l10n.eventTypeHoliday;
      case SchoolEventType.exam:
        return l10n.eventTypeExam;
      case SchoolEventType.test:
        return l10n.eventTypeTest;
      case SchoolEventType.event:
        return l10n.eventTypeEvent;
    }
  }

  Future<void> _addEvent() async {
    final result = await showDialog<_EventFormResult>(
      context: context,
      builder: (context) => const _EventFormDialog(),
    );
    if (result == null) return;

    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<CalendarService>().createEvent(
            title: result.title,
            description: result.description,
            eventType: result.eventType,
            startDate: result.startDate,
            endDate: result.endDate,
          );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorPrefix(e.toString()))));
      }
    }
  }

  Future<void> _deleteEvent(SchoolEvent event) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteEventTitle),
        content: Text(l10n.deleteEventConfirm),
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
      await context.read<CalendarService>().deleteEvent(event.id);
      setState(() => _events?.removeWhere((e) => e.id == event.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorPrefix(e.toString()))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDirector = !_isParent && context.watch<AuthProvider>().role == AppRole.director;
    final events = _events;

    return AppShell(
      title: l10n.schoolCalendar,
      actions: [
        if (isDirector)
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _addEvent, tooltip: l10n.addEvent),
      ],
      child: _loading
          ? const AppLoadingIndicator()
          : _error != null
              ? Center(child: Text(l10n.errorPrefix(_error!)))
              : events == null || events.isEmpty
                  ? EmptyState(icon: Icons.event_note_outlined, title: l10n.noDataTitle, message: l10n.noUpcomingEvents)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: (const EdgeInsets.fromLTRB(16, 8, 16, 16)).add(bottomNavPadding(context)),
                        itemCount: events.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, listIndex) {
                          if (listIndex == 0) {
                            return DashboardSectionHeader(title: l10n.schoolCalendar);
                          }
                          final index = listIndex - 1;
                          final event = events[index];
                          return FadeSlideIn(
                            delay: index < 12
                                ? Duration(milliseconds: 40 * index)
                                : Duration.zero,
                            child: _EventCard(
                              event: event,
                              color: _colorFor(context, event.eventType),
                              typeLabel: _labelFor(l10n, event.eventType),
                              dateRange: _formatDate(event),
                              onDelete: isDirector ? () => _deleteEvent(event) : null,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  String _formatDate(SchoolEvent event) {
    String fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    if (event.endDate == null || event.endDate == event.startDate) return fmt(event.startDate);
    return '${fmt(event.startDate)} — ${fmt(event.endDate!)}';
  }
}

class _EventFormResult {
  const _EventFormResult({
    required this.title,
    this.description,
    required this.eventType,
    required this.startDate,
    this.endDate,
  });

  final String title;
  final String? description;
  final SchoolEventType eventType;
  final DateTime startDate;
  final DateTime? endDate;
}

class _EventFormDialog extends StatefulWidget {
  const _EventFormDialog();

  @override
  State<_EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<_EventFormDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  SchoolEventType _eventType = SchoolEventType.event;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typeLabels = {
      SchoolEventType.holiday: l10n.eventTypeHoliday,
      SchoolEventType.exam: l10n.eventTypeExam,
      SchoolEventType.test: l10n.eventTypeTest,
      SchoolEventType.event: l10n.eventTypeEvent,
    };

    return AlertDialog(
      title: Text(l10n.addEvent),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: l10n.eventTitleLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(labelText: l10n.eventDescriptionLabel),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SchoolEventType>(
              value: _eventType,
              isExpanded: true,
              items: typeLabels.entries
                  .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _eventType = value);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: Text(_fmt(_startDate)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: false),
                    child: Text(_endDate != null ? _fmt(_endDate!) : '—'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _EventFormResult(
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                eventType: _eventType,
                startDate: _startDate,
                endDate: _endDate,
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// One calendar entry, led by its date.
///
/// The previous card opened with a coloured type chip and buried the date at
/// the far right of the same row, so scanning a list for "when is this?"
/// meant reading every card end to end. Here the day sits in a badge on the
/// left -- the way a calendar is actually read -- with the type reduced to a
/// coloured dot beside the range. Entries whose end date has passed are
/// dimmed so the upcoming ones stand out.
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.color,
    required this.typeLabel,
    required this.dateRange,
    this.onDelete,
  });

  final SchoolEvent event;
  final Color color;
  final String typeLabel;
  final String dateRange;
  final VoidCallback? onDelete;

  bool get _isPast {
    final last = event.endDate ?? event.startDate;
    final today = DateTime.now();
    return last.isBefore(DateTime(today.year, today.month, today.day));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final past = _isPast;
    final accent = past ? context.colors.textMuted : color;
    final description = event.description;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: AppGradients.tint(accent),
              borderRadius: AppRadius.mdRadius,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${event.startDate.day}',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    height: 1.05,
                  ),
                ),
                Text(
                  DateFormatters.monthName(l10n, event.startDate.month),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    color: past ? context.colors.textSecondary : context.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$typeLabel · $dateRange',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.colors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: context.colors.danger),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}
