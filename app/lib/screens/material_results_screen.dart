import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/material.dart';
import '../services/material_service.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';

/// What the class did with a piece of work -- and the one screen where a
/// teacher turns it into journal marks.
///
/// The screen deliberately shows two quite different things depending on
/// [AssignmentResults.resultsVisible]. While a control test is still
/// running, a teacher sees only who has finished; that's the school's rule,
/// so the first pupil to finish can't tell the rest what the answers were.
class MaterialResultsScreen extends StatefulWidget {
  const MaterialResultsScreen({super.key, required this.assignmentId});

  final int assignmentId;

  @override
  State<MaterialResultsScreen> createState() => _MaterialResultsScreenState();
}

class _MaterialResultsScreenState extends State<MaterialResultsScreen> {
  AssignmentResults? _results;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// Marks the teacher has adjusted away from the suggestion.
  final Map<int, int> _overrides = {};
  bool _dirty = false;

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
      final results = await context.read<MaterialService>().fetchResults(widget.assignmentId);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _markFor(AssignmentResultRow row) => _overrides[row.studentId] ?? row.suggestedGrade;

  Future<void> _transfer() async {
    final results = _results;
    if (results == null) return;

    // Only pupils who actually submitted and haven't been graded from this
    // work already -- sending a mark for someone who never did it would
    // put a grade in the journal out of nowhere.
    final marks = <int, int>{};
    for (final row in results.rows) {
      if (!row.hasSubmitted || row.transferred) continue;
      final mark = _markFor(row);
      if (mark != null) marks[row.studentId] = mark;
    }
    if (marks.isEmpty) return;

    setState(() => _saving = true);
    try {
      final updated =
          await context.read<MaterialService>().transferGrades(widget.assignmentId, marks);
      if (!mounted) return;
      setState(() {
        _results = updated;
        _overrides.clear();
        _dirty = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.materialTransferDone)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editMark(AssignmentResultRow row) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                row.studentName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                children: [
                  for (final value in [2, 3, 4, 5])
                    ChoiceChip(
                      label: Text('$value'),
                      selected: _markFor(row) == value,
                      onSelected: (_) => Navigator.pop(sheetContext, value),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _overrides[row.studentId] = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final results = _results;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _dirty);
      },
      child: AppShell(
        title: results?.assignment.materialTitle ?? l10n.materialResults,
        child: _loading
            ? const AppLoadingIndicator()
            : _error != null || results == null
                ? Center(child: Text(l10n.errorPrefix(_error ?? '')))
                : Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: (const EdgeInsets.fromLTRB(16, 12, 16, 24)).add(bottomNavPadding(context)),
                            children: [
                              _Header(assignment: results.assignment),
                              if (!results.resultsVisible) ...[
                                const SizedBox(height: 12),
                                _LockNotice(text: l10n.materialResultsHidden),
                              ],
                              const SizedBox(height: 16),
                              for (final row in results.rows)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ResultRow(
                                    row: row,
                                    resultsVisible: results.resultsVisible,
                                    isControl: results.assignment.isControl,
                                    mark: _markFor(row),
                                    onEditMark:
                                        results.resultsVisible && row.hasSubmitted && !row.transferred
                                            ? () => _editMark(row)
                                            : null,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (results.resultsVisible &&
                          results.assignment.isControl &&
                          results.rows.any((r) => r.hasSubmitted && !r.transferred))
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _saving ? null : _transfer,
                                icon: const Icon(Icons.library_books_rounded, size: 18),
                                label: Text(l10n.materialTransfer),
                                style: FilledButton.styleFrom(backgroundColor: colors.success),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.assignment});

  final MaterialAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: AppRadius.lgRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${assignment.className ?? ''} · ${assignment.subject}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.materialSubmittedOf(assignment.submittedCount, assignment.studentCount),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: assignment.studentCount == 0
                  ? 0
                  : assignment.submittedCount / assignment.studentCount,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                assignment.isControl
                    ? Icons.fact_check_rounded
                    : Icons.fitness_center_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Text(
                assignment.isControl ? l10n.materialModeControl : l10n.materialModePractice,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
              ),
              if (assignment.dueAt != null) ...[
                const SizedBox(width: 14),
                Icon(Icons.schedule_rounded,
                    size: 14, color: Colors.white.withValues(alpha: 0.85)),
                const SizedBox(width: 6),
                Text(
                  _formatDue(assignment.dueAt!.toLocal()),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                ),
              ],
            ],
          ),
          if (assignment.gradesTransferredAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  l10n.materialTransferred,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ],
          // Deliberately absent while a control test is running: nothing
          // here reveals a single mark. See _LockNotice below.
          const SizedBox.shrink(),
        ],
      ),
    );
  }

  String _formatDue(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)} ${two(value.hour)}:${two(value.minute)}';
  }
}

class _LockNotice extends StatelessWidget {
  const _LockNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.10),
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: colors.info.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock_rounded, size: 18, color: colors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.row,
    required this.resultsVisible,
    required this.isControl,
    required this.mark,
    this.onEditMark,
  });

  final AssignmentResultRow row;
  final bool resultsVisible;
  final bool isControl;
  final int? mark;
  final VoidCallback? onEditMark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    final subtitle = !row.hasSubmitted
        ? l10n.materialNotSubmitted
        : !resultsVisible
            ? l10n.assignmentDone
            : '${row.score}/${row.maxScore} · ${row.percent}%';

    Widget? trailing;
    if (row.transferred) {
      trailing = AppListBadge(text: '$mark', color: colors.success);
    } else if (resultsVisible && isControl && row.hasSubmitted) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppListBadge(text: mark == null ? '—' : '$mark', color: colors.primary),
          Icon(Icons.edit_rounded, size: 15, color: colors.textMuted),
        ],
      );
    } else if (row.hasSubmitted) {
      trailing = Icon(Icons.check_circle_rounded, size: 20, color: colors.success);
    } else {
      trailing = Icon(Icons.remove_circle_outline_rounded, size: 20, color: colors.textMuted);
    }

    return AppListCard(
      title: row.studentName,
      subtitle: subtitle,
      showChevron: false,
      leading: Icon(
        row.hasSubmitted ? Icons.person_rounded : Icons.person_outline_rounded,
        size: 20,
        color: row.hasSubmitted ? colors.primary : colors.textMuted,
      ),
      trailing: trailing,
      onTap: onEditMark,
    );
  }
}
