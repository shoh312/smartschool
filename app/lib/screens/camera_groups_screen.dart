import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/camera_config.dart';
import '../models/camera_position.dart';
import '../models/school_class.dart';
import '../providers/school_provider.dart';
import '../services/school_service.dart';
import '../utils/error_formatter.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';

/// Who is in front of one camera, and when.
///
/// Lives inside the camera rather than inside the group on purpose. A slot is
/// a fact about a *room*, and the room is what the director thinks of as "the
/// camera" -- and only here can two groups claiming the same hour be seen
/// next to each other. Split across the groups, that collision would sit on
/// two screens and nobody would notice it until the day it mattered.
class CameraGroupsScreen extends StatefulWidget {
  const CameraGroupsScreen({super.key, required this.camera});

  final CameraConfig camera;

  @override
  State<CameraGroupsScreen> createState() => _CameraGroupsScreenState();
}

class _CameraGroupsScreenState extends State<CameraGroupsScreen> {
  List<CameraPosition>? _positions;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final rows = await context.read<SchoolService>().fetchPositions(widget.camera.id);
      if (mounted) setState(() => _positions = rows);
    } catch (exception) {
      if (mounted) setState(() => _error = classifyError(exception));
    }
  }

  Future<void> _add() async {
    final classes = context.read<SchoolProvider>().classes;
    if (classes.isEmpty) return;

    final result = await showModalBottomSheet<_SlotDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SlotSheet(classes: classes),
    );
    if (result == null || !mounted) return;

    try {
      await context.read<SchoolService>().createPosition(
            cameraId: widget.camera.id,
            classId: result.classId,
            startTime: result.startTime,
            endTime: result.endTime,
            subject: result.subject,
            dayOfWeek: result.dayOfWeek,
          );
      await _load();
    } catch (exception) {
      if (!mounted) return;
      // The overlap message from the server names the slot it collides with,
      // which is more use than "failed".
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanReadableError(
          classifyError(exception),
          AppLocalizations.of(context)!,
        ))),
      );
    }
  }

  Future<void> _delete(CameraPosition position) async {
    try {
      await context.read<SchoolService>().deletePosition(widget.camera.id, position.id);
      await _load();
    } catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanReadableError(
          classifyError(exception),
          AppLocalizations.of(context)!,
        ))),
      );
    }
  }

  String _dayLabel(AppLocalizations l10n, int? day) => switch (day) {
        0 => l10n.weekday1,
        1 => l10n.weekday2,
        2 => l10n.weekday3,
        3 => l10n.weekday4,
        4 => l10n.weekday5,
        5 => l10n.weekday6,
        _ => l10n.everyDay,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final positions = _positions;

    return AppShell(
      title: widget.camera.name,
      child: positions == null && _error == null
          ? const AppLoadingIndicator()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Text(
                    l10n.cameraGroupsHint,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (positions != null && positions.isEmpty)
                    SizedBox(
                      height: 240,
                      child: EmptyState(
                        icon: Icons.schedule_outlined,
                        title: l10n.noGroupSlots,
                        message: l10n.cameraGroupsHint,
                      ),
                    ),
                  for (final position in positions ?? <CameraPosition>[])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppListCard(
                        leading: AppListBadge(
                          icon: Icons.groups_2_outlined,
                          color: context.colors.primary,
                        ),
                        title: position.subject?.isNotEmpty == true
                            ? '${position.className ?? ''} · ${position.subject}'
                            : (position.className ?? '—'),
                        subtitle:
                            '${position.startTime} – ${position.endTime} · ${_dayLabel(l10n, position.dayOfWeek)}',
                        showChevron: false,
                        trailing: IconButton(
                          tooltip: l10n.deleteSlot,
                          icon: Icon(Icons.remove_circle_outline,
                              color: context.colors.danger, size: 22),
                          onPressed: () => _delete(position),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addGroupSlot),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SlotDraft {
  const _SlotDraft({
    required this.classId,
    required this.startTime,
    required this.endTime,
    this.subject,
    this.dayOfWeek,
  });

  final int classId;
  final String startTime;
  final String endTime;
  final String? subject;
  final int? dayOfWeek;
}

class _SlotSheet extends StatefulWidget {
  const _SlotSheet({required this.classes});

  final List<SchoolClass> classes;

  @override
  State<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends State<_SlotSheet> {
  final _subjectController = TextEditingController();
  SchoolClass? _selected;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 11, minute: 0);
  int? _day;

  @override
  void initState() {
    super.initState();
    _selected = widget.classes.first;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  String _text(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final valid = _selected != null &&
        (_end.hour * 60 + _end.minute) > (_start.hour * 60 + _start.minute);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: context.colors.borderStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            DropdownButtonFormField<SchoolClass>(
              value: _selected,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.cameraGroups),
              items: [
                for (final schoolClass in widget.classes)
                  DropdownMenuItem(value: schoolClass, child: Text(schoolClass.name)),
              ],
              onChanged: (value) => setState(() => _selected = value),
            ),
            const SizedBox(height: 14),
            // Optional: left blank it becomes the group's own name, which for
            // an academy ("PYTHON 4") is the subject anyway. It is what the
            // generated lessons carry, so it decides which column an absence
            // lands in.
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: l10n.subjectLabel,
                hintText: _selected?.name ?? '',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(true),
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(_text(_start)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(false),
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(_text(_end)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Every day by default: an academy's timetable is usually the
            // same group at the same hour all week, and a per-day slot is the
            // exception rather than the rule.
            DropdownButtonFormField<int?>(
              value: _day,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.everyDay),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.everyDay)),
                DropdownMenuItem(value: 0, child: Text(l10n.weekday1)),
                DropdownMenuItem(value: 1, child: Text(l10n.weekday2)),
                DropdownMenuItem(value: 2, child: Text(l10n.weekday3)),
                DropdownMenuItem(value: 3, child: Text(l10n.weekday4)),
                DropdownMenuItem(value: 4, child: Text(l10n.weekday5)),
                DropdownMenuItem(value: 5, child: Text(l10n.weekday6)),
              ],
              onChanged: (value) => setState(() => _day = value),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: valid
                  ? () => Navigator.pop(
                        context,
                        _SlotDraft(
                          classId: _selected!.id,
                          startTime: _text(_start),
                          endTime: _text(_end),
                          subject: _subjectController.text,
                          dayOfWeek: _day,
                        ),
                      )
                  : null,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
