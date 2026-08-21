import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/class_assignment.dart';
import '../models/material.dart';
import '../services/material_service.dart';
import '../services/teacher_service.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';

/// Handing a material to one or more classes, with the rules that decide
/// how it behaves: graded control work versus practice, deadline, and how
/// many goes each pupil gets.
class MaterialAssignScreen extends StatefulWidget {
  const MaterialAssignScreen({super.key, required this.material});

  final LearningMaterial material;

  @override
  State<MaterialAssignScreen> createState() => _MaterialAssignScreenState();
}

class _MaterialAssignScreenState extends State<MaterialAssignScreen> {
  List<ClassAssignment> _classes = [];
  final Set<int> _selected = {};

  AssignmentMode _mode = AssignmentMode.practice;
  DateTime? _dueAt;
  int? _maxAttempts;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final classes = await context.read<TeacherService>().myClasses();
      if (!mounted) return;
      // Only where this teacher takes this material's subject: handing a
      // maths test to the class they teach physics in would be rejected by
      // the server anyway, so don't offer it.
      // A null/blank subject on the assignment row means "any subject" (see
      // teacher_can_grade_class on the server), so those stay in the list.
      setState(() => _classes = classes
          .where((c) =>
              (c.subject ?? '').isEmpty || c.subject == widget.material.subject)
          .toList());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt ?? DateTime(0, 1, 1, 20, 0)),
    );
    if (!mounted) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 20,
        time?.minute ?? 0,
      );
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selected.isEmpty) {
      _toast(l10n.materialPickAtLeastOne);
      return;
    }
    if (_mode == AssignmentMode.control && _dueAt == null) {
      // Not just the server's rule repeated: without a deadline a control
      // test can only unlock once every single pupil submits, so one absent
      // pupil would keep the marks locked away for good.
      _toast(l10n.materialControlNeedsDue);
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<MaterialService>().assign(
            materialId: widget.material.id,
            classIds: _selected.toList(),
            mode: _mode,
            dueAt: _dueAt,
            maxAttempts: _maxAttempts,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return AppShell(
      title: l10n.materialAssignTitle,
      child: _loading
          ? const AppLoadingIndicator()
          : _error != null
              ? Center(child: Text(l10n.errorPrefix(_error!)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: (const EdgeInsets.fromLTRB(16, 12, 16, 24)).add(bottomNavPadding(context)),
                        children: [
                          _SectionLabel(l10n.materialPickClasses),
                          for (final item in _classes)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppListCard(
                                title: item.className ?? '#${item.classId}',
                                subtitle: (item.subject ?? '').isEmpty ? null : item.subject,
                                showChevron: false,
                                leading: Icon(
                                  _selected.contains(item.classId)
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  color: _selected.contains(item.classId)
                                      ? colors.success
                                      : colors.textMuted,
                                ),
                                onTap: () => setState(() {
                                  if (!_selected.remove(item.classId)) {
                                    _selected.add(item.classId);
                                  }
                                }),
                              ),
                            ),
                          const SizedBox(height: 20),
                          _SectionLabel(l10n.materialMode),
                          _ModeTile(
                            label: l10n.materialModePractice,
                            hint: l10n.materialModePracticeHint,
                            icon: Icons.fitness_center_rounded,
                            selected: _mode == AssignmentMode.practice,
                            onTap: () => setState(() => _mode = AssignmentMode.practice),
                          ),
                          const SizedBox(height: 8),
                          _ModeTile(
                            label: l10n.materialModeControl,
                            hint: l10n.materialModeControlHint,
                            icon: Icons.fact_check_rounded,
                            selected: _mode == AssignmentMode.control,
                            onTap: () => setState(() {
                              _mode = AssignmentMode.control;
                              // Control work is one go by convention; the
                              // teacher can still raise it below.
                              _maxAttempts ??= 1;
                            }),
                          ),
                          const SizedBox(height: 20),
                          _SectionLabel(l10n.materialDueAt),
                          AppListCard(
                            title: _dueAt == null
                                ? l10n.materialPickDue
                                : _formatDue(_dueAt!),
                            leading: Icon(Icons.event_rounded, color: colors.primary, size: 20),
                            trailing: _dueAt == null
                                ? null
                                : IconButton(
                                    icon: Icon(Icons.close_rounded,
                                        size: 18, color: colors.textMuted),
                                    onPressed: () => setState(() => _dueAt = null),
                                  ),
                            onTap: _pickDue,
                          ),
                          const SizedBox(height: 20),
                          _SectionLabel(l10n.materialAttempts),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final option in <int?>[1, 2, 3, null])
                                ChoiceChip(
                                  label: Text(option?.toString() ??
                                      l10n.materialAttemptsUnlimited),
                                  selected: _maxAttempts == option,
                                  onSelected: (_) => setState(() => _maxAttempts = option),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _submit,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: Text(l10n.materialAssign),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  String _formatDue(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year}  ${two(value.hour)}:${two(value.minute)}';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.2,
            color: context.colors.textSecondary,
          ),
        ),
      );
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgRadius,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? colors.primary.withValues(alpha: 0.08) : colors.surface,
            borderRadius: AppRadius.lgRadius,
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: selected ? colors.primary : colors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hint,
                      style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
