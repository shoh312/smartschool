import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/material.dart';
import '../services/material_service.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/bottom_nav_inset.dart';

/// One screen at a time: read a page, tap Next, answer a question, tap Next.
///
/// The two things that make it feel like a game rather than a form:
/// a progress bar that only counts questions (pages aren't work), and
/// immediate right/wrong feedback -- but *only* in practice mode. In a
/// control test the pupil is told nothing at all, so the first to finish
/// can't relay the answers to everyone else.
///
/// Every answer is saved as it's given, so closing the app loses nothing.
class AssignmentPlayerScreen extends StatefulWidget {
  const AssignmentPlayerScreen({
    super.key,
    required this.assignmentId,
    required this.studentId,
  });

  final int assignmentId;
  final int studentId;

  @override
  State<AssignmentPlayerScreen> createState() => _AssignmentPlayerScreenState();
}

class _AssignmentPlayerScreenState extends State<AssignmentPlayerScreen> {
  StudentAssignment? _assignment;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  int _index = 0;

  /// The pupil's current answer for the block on screen, in the shape the
  /// server expects. Null until they've picked something.
  dynamic _draft;

  /// Set after Check in practice mode; null means "not checked yet".
  bool? _verdict;

  AttemptResult? _result;

  /// Per-block shuffle for ordering questions, kept so the words don't jump
  /// around every rebuild.
  final Map<int, List<int>> _shuffles = {};

  /// Match questions: which left item is waiting for a partner.
  int? _pendingLeft;
  final Map<int, Map<int, int>> _matchPairs = {};

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _loading = true);
    try {
      final assignment = await context
          .read<MaterialService>()
          .startAttempt(widget.assignmentId, widget.studentId);
      if (!mounted) return;
      setState(() {
        _assignment = assignment;
        // Resume where they stopped: the first block they haven't answered.
        _index = _firstUnanswered(assignment);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _firstUnanswered(StudentAssignment assignment) {
    for (var i = 0; i < assignment.blocks.length; i++) {
      final block = assignment.blocks[i];
      if (!block.isQuestion) continue;
      if (!assignment.savedAnswers.containsKey('${block.id}')) return i;
    }
    return 0;
  }

  MaterialBlock? get _block {
    final blocks = _assignment?.blocks ?? const <MaterialBlock>[];
    return _index >= 0 && _index < blocks.length ? blocks[_index] : null;
  }

  int get _questionCount =>
      _assignment?.blocks.where((b) => b.isQuestion).length ?? 0;

  int get _questionsDone {
    final blocks = _assignment?.blocks ?? const <MaterialBlock>[];
    return blocks.take(_index).where((b) => b.isQuestion).length;
  }

  bool get _isLast => _index >= (_assignment?.blocks.length ?? 1) - 1;

  // ------------------------------------------------------------------
  // Advancing
  // ------------------------------------------------------------------

  Future<void> _primaryAction() async {
    final assignment = _assignment;
    final block = _block;
    if (assignment == null || block == null) return;

    // Explanation page: nothing to send, just turn the page.
    if (!block.isQuestion) {
      _advance();
      return;
    }

    // Practice mode has two taps per question -- Check, then Next -- so the
    // pupil gets a beat to see whether they were right.
    if (_verdict != null) {
      _advance();
      return;
    }

    if (_draft == null) return;

    setState(() => _busy = true);
    try {
      final correct = await context.read<MaterialService>().submitAnswer(
            attemptId: assignment.attemptId!,
            blockId: block.id!,
            answer: _draft,
          );
      if (!mounted) return;
      if (correct == null) {
        // Control mode: no feedback, straight on.
        _advance();
      } else {
        setState(() => _verdict = correct);
      }
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _advance() {
    if (_isLast) {
      _finish();
      return;
    }
    setState(() {
      _index += 1;
      _draft = null;
      _verdict = null;
      _pendingLeft = null;
    });
  }

  Future<void> _finish() async {
    final assignment = _assignment;
    if (assignment?.attemptId == null) return;
    setState(() => _busy = true);
    try {
      final result =
          await context.read<MaterialService>().finishAttempt(assignment!.attemptId!);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmLeave() async {
    if (_result != null) return true;
    final l10n = AppLocalizations.of(context)!;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(l10n.assignmentLeave),
        content: Text(l10n.assignmentLeaveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  /// Asks, then leaves. A method on the State rather than a closure in
  /// `build` so the `mounted` guard refers to this widget and not to the
  /// build callback's shadowed context.
  Future<void> _leave() async {
    if (!await _confirmLeave()) return;
    if (!mounted) return;
    Navigator.pop(context, _result != null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: _loading
              ? const AppLoadingIndicator()
              : _error != null
                  ? Center(child: Text(l10n.errorPrefix(_error!)))
                  : _result != null
                      ? _ResultView(
                          result: _result!,
                          assignment: _assignment!,
                          onClose: () => Navigator.pop(context, true),
                        )
                      : _buildRunner(l10n, colors),
        ),
      ),
    );
  }

  Widget _buildRunner(AppLocalizations l10n, AppColorScheme colors) {
    final block = _block;
    if (block == null) return const SizedBox.shrink();

    final canContinue = !block.isQuestion || _verdict != null || _draft != null;

    return Column(
      children: [
        _TopBar(
          done: _questionsDone,
          total: _questionCount,
          onClose: _leave,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: (const EdgeInsets.fromLTRB(20, 8, 20, 20)).add(bottomNavPadding(context)),
            child: block.isQuestion
                ? _buildQuestion(block, l10n, colors)
                : _buildPage(block, colors),
          ),
        ),
        if (_verdict != null) _VerdictBar(correct: _verdict!),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _busy || !canContinue ? null : _primaryAction,
              style: FilledButton.styleFrom(
                backgroundColor: _verdict == false ? colors.danger : colors.primary,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
              ),
              child: Text(
                !block.isQuestion
                    ? l10n.assignmentNext
                    : _verdict != null
                        ? (_isLast ? l10n.assignmentFinish : l10n.assignmentNext)
                        : (_isLast && _assignment!.isControl
                            ? l10n.assignmentFinish
                            : l10n.assignmentCheck),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPage(MaterialBlock block, AppColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Icon(Icons.auto_stories_rounded, size: 34, color: colors.primary),
        const SizedBox(height: 18),
        Text(
          block.body,
          style: TextStyle(fontSize: 17, height: 1.55, color: colors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildQuestion(MaterialBlock block, AppLocalizations l10n, AppColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          block.body,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            height: 1.4,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        switch (block.questionType) {
          QuestionType.single => _singleChoice(block, colors),
          QuestionType.trueFalse => _trueFalse(l10n, colors),
          QuestionType.fill => _fillIn(l10n, colors),
          QuestionType.order => _ordering(block, l10n, colors),
          QuestionType.match => _matching(block, l10n, colors),
          null => const SizedBox.shrink(),
        },
      ],
    );
  }

  // ------------------------------------------------------------------
  // Answer widgets
  // ------------------------------------------------------------------

  /// A stable display order for a block's options.
  ///
  /// Without this the answer is often guessable from position alone: the
  /// paste importer keeps options in the order they were typed, and a
  /// teacher writing "* correct" first (the natural way to write it) would
  /// put the right answer at the top of every single question. Seeded on
  /// the block id so the order doesn't reshuffle on every rebuild.
  List<int> _displayOrder(int key, int count) => _shuffles.putIfAbsent(key, () {
        final indexes = List<int>.generate(count, (i) => i);
        indexes.shuffle(Random(key));
        return indexes;
      });

  Widget _singleChoice(MaterialBlock block, AppColorScheme colors) {
    final options = block.optionList;
    final order = _displayOrder(block.id ?? _index, options.length);
    final chosen = _draft is Map ? (_draft as Map)['index'] as int? : null;
    return Column(
      children: [
        for (final real in order)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionTile(
              label: options[real],
              selected: chosen == real,
              locked: _verdict != null,
              // The answer carries the *authored* index, so shuffling is
              // purely a display concern the server never sees.
              onTap: () => setState(() => _draft = {'index': real}),
            ),
          ),
      ],
    );
  }

  Widget _trueFalse(AppLocalizations l10n, AppColorScheme colors) {
    final chosen = _draft is Map ? (_draft as Map)['value'] as bool? : null;
    return Row(
      children: [
        for (final entry in {true: l10n.materialTrue, false: l10n.materialFalse}.entries)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: entry.key ? 10 : 0),
              child: _OptionTile(
                label: entry.value,
                selected: chosen == entry.key,
                locked: _verdict != null,
                onTap: () => setState(() => _draft = {'value': entry.key}),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fillIn(AppLocalizations l10n, AppColorScheme colors) {
    return TextField(
      enabled: _verdict == null,
      autofocus: true,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: l10n.assignmentTypeAnswer,
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
      ),
      style: const TextStyle(fontSize: 17),
      onChanged: (value) => setState(
        () => _draft = value.trim().isEmpty ? null : {'text': value},
      ),
    );
  }

  Widget _ordering(MaterialBlock block, AppLocalizations l10n, AppColorScheme colors) {
    final items = block.optionList;
    // Shuffled once per block: the pupil's job is to restore the order, so
    // showing them the authored (correct) order would give it away.
    final order = _displayOrder(block.id ?? _index, items.length);

    final picked = _draft is Map ? List<int>.from((_draft as Map)['order'] as List? ?? []) : <int>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.assignmentTapInOrder,
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: AppRadius.mdRadius,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final index in picked)
                _Chip(
                  label: items[index],
                  onTap: _verdict != null
                      ? null
                      : () => setState(() {
                            final next = List<int>.from(picked)..remove(index);
                            _draft = next.isEmpty ? null : {'order': next};
                          }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final index in order)
              if (!picked.contains(index))
                _Chip(
                  label: items[index],
                  outlined: true,
                  onTap: _verdict != null
                      ? null
                      : () => setState(() {
                            _draft = {'order': [...picked, index]};
                          }),
                ),
          ],
        ),
      ],
    );
  }

  Widget _matching(MaterialBlock block, AppLocalizations l10n, AppColorScheme colors) {
    final options = block.options;
    final left = (options is Map && options['left'] is List)
        ? (options['left'] as List).map((e) => '$e').toList()
        : <String>[];
    final right = (options is Map && options['right'] is List)
        ? (options['right'] as List).map((e) => '$e').toList()
        : <String>[];

    final pairs = _matchPairs.putIfAbsent(block.id ?? _index, () => {});

    void join(int leftIndex, int rightIndex) {
      setState(() {
        // One partner each: re-picking replaces the old link rather than
        // stacking a second one the pupil can't see or undo.
        pairs.removeWhere((_, value) => value == rightIndex);
        pairs[leftIndex] = rightIndex;
        _pendingLeft = null;
        _draft = pairs.length == left.length
            ? {'pairs': pairs.entries.map((e) => [e.key, e.value]).toList()}
            : null;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.assignmentMatchHint,
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < left.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _OptionTile(
                        label: left[i],
                        selected: _pendingLeft == i || pairs.containsKey(i),
                        locked: _verdict != null,
                        dense: true,
                        onTap: () => setState(() => _pendingLeft = i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  // Right-hand column shuffled for the same reason as the
                  // options above: the editor authors row i against row i,
                  // so shown in order the whole question solves itself.
                  for (final j in _displayOrder(-(block.id ?? _index) - 1, right.length))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _OptionTile(
                        label: right[j],
                        selected: pairs.containsValue(j),
                        locked: _verdict != null,
                        dense: true,
                        onTap: _pendingLeft == null ? null : () => join(_pendingLeft!, j),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Pieces
// --------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.done, required this.total, required this.onClose});

  final int done;
  final int total;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: colors.textMuted),
            onPressed: onClose,
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 10,
                backgroundColor: colors.surfaceSunken,
                valueColor: AlwaysStoppedAnimation(colors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$done/$total',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.locked,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: AppRadius.mdRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 12 : 16),
          decoration: BoxDecoration(
            color: selected ? colors.primary.withValues(alpha: 0.10) : colors.surface,
            borderRadius: AppRadius.mdRadius,
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: dense ? 14 : 16,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.onTap, this.outlined = false});

  final String label;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: outlined ? colors.surface : colors.primary.withValues(alpha: 0.12),
            borderRadius: AppRadius.smRadius,
            border: Border.all(color: outlined ? colors.border : colors.primary),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _VerdictBar extends StatelessWidget {
  const _VerdictBar({required this.correct});

  final bool correct;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final tint = correct ? colors.success : colors.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: tint.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: tint,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            correct ? l10n.assignmentCorrect : l10n.assignmentWrong,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tint),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.assignment,
    required this.onClose,
  });

  final AttemptResult result;
  final StudentAssignment assignment;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            result.scoreVisible ? Icons.emoji_events_rounded : Icons.lock_clock_rounded,
            size: 64,
            color: result.scoreVisible ? colors.warning : colors.info,
          ),
          const SizedBox(height: 24),
          if (result.scoreVisible) ...[
            Text(
              l10n.assignmentYourScore,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              '${result.score}/${result.maxScore}',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            Text(
              '${result.percent}%',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ] else
            // Control work: the pupil is told it arrived, and nothing more.
            Text(
              l10n.assignmentWaitingMark,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5, color: colors.textPrimary),
            ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
              ),
              child: Text(l10n.close,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
