import 'package:flutter/material.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../../core/design_tokens.dart';
import '../../models/material.dart';
import '../app_list_card.dart';
import '../app_shell.dart';
import '../bottom_nav_inset.dart';

/// One block of a material, and the screen that edits it.
///
/// Shared by the hand-written editor and the AI wizard's review step. Both
/// show the same list of pages and questions, and a teacher checking what
/// the model wrote should be editing it with exactly the controls they use
/// to write one themselves -- two near-identical copies would drift, and
/// the AI one would be the one missing the newest question type.

/// Opens the block editor and returns the edited block, or null if the
/// teacher backed out.
Future<MaterialBlock?> editMaterialBlock(BuildContext context, MaterialBlock block) {
  return Navigator.push<MaterialBlock>(
    context,
    MaterialPageRoute(builder: (_) => _BlockEditorScreen(block: block)),
  );
}

class MaterialBlockRow extends StatelessWidget {
  const MaterialBlockRow({
    super.key,
    required this.block,
    required this.index,
    this.locked = false,
    this.onTap,
    this.onRemove,
    this.onMoveUp,
  });

  final MaterialBlock block;
  final int index;

  /// Read-only: no remove or reorder controls. True for a colleague's
  /// material, or one already handed out. An AI draft is never locked --
  /// editing it is the entire point of the review step.
  final bool locked;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onMoveUp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final isQuestion = block.isQuestion;

    final label = isQuestion
        ? switch (block.questionType) {
            QuestionType.single => l10n.materialTypeSingle,
            QuestionType.trueFalse => l10n.materialTypeTrueFalse,
            QuestionType.fill => l10n.materialTypeFill,
            QuestionType.match => l10n.materialTypeMatch,
            QuestionType.order => l10n.materialTypeOrder,
            null => l10n.materialQuestion,
          }
        : l10n.materialPage;

    return AppListCard(
      title: block.body.isEmpty ? label : block.body,
      subtitle: label,
      subtitleMaxLines: 1,
      showChevron: false,
      leading: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: (isQuestion ? colors.primary : colors.info).withValues(alpha: 0.12),
          borderRadius: AppRadius.smRadius,
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: isQuestion ? colors.primary : colors.info,
          ),
        ),
      ),
      trailing: locked
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onMoveUp != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.arrow_upward_rounded, size: 18, color: colors.textMuted),
                    onPressed: onMoveUp,
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 18, color: colors.danger),
                  onPressed: onRemove,
                ),
              ],
            ),
      onTap: onTap,
    );
  }
}

// --------------------------------------------------------------------------
// One block, on its own screen
// --------------------------------------------------------------------------

class _BlockEditorScreen extends StatefulWidget {
  const _BlockEditorScreen({required this.block});

  final MaterialBlock block;

  @override
  State<_BlockEditorScreen> createState() => _BlockEditorScreenState();
}

class _BlockEditorScreenState extends State<_BlockEditorScreen> {
  late final TextEditingController _bodyController;
  late List<TextEditingController> _optionControllers;
  late TextEditingController _fillController;
  late List<TextEditingController> _leftControllers;
  late List<TextEditingController> _rightControllers;

  int _correctIndex = 0;
  bool _trueFalseValue = true;

  MaterialBlock get _block => widget.block;

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController(text: _block.body);

    final options = _block.optionList;
    _optionControllers = [
      for (final option in options.isEmpty ? ['', ''] : options)
        TextEditingController(text: option),
    ];

    final correct = _block.correct;
    _correctIndex = (correct is Map && correct['index'] is int) ? correct['index'] as int : 0;
    _trueFalseValue = (correct is Map && correct['value'] is bool) ? correct['value'] as bool : true;

    final accepted = (correct is Map && correct['answers'] is List)
        ? (correct['answers'] as List).map((e) => '$e').toList()
        : <String>[];
    _fillController = TextEditingController(text: accepted.join('\n'));

    final matchOptions = _block.options;
    final left = (matchOptions is Map && matchOptions['left'] is List)
        ? (matchOptions['left'] as List).map((e) => '$e').toList()
        : <String>[''];
    final right = (matchOptions is Map && matchOptions['right'] is List)
        ? (matchOptions['right'] as List).map((e) => '$e').toList()
        : <String>[''];
    _leftControllers = [for (final item in left) TextEditingController(text: item)];
    _rightControllers = [for (final item in right) TextEditingController(text: item)];
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _fillController.dispose();
    for (final controller in [..._optionControllers, ..._leftControllers, ..._rightControllers]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _done() {
    final body = _bodyController.text.trim();
    if (_block.blockType == BlockType.page) {
      Navigator.pop(context, _block.copyWith(body: body));
      return;
    }

    switch (_block.questionType) {
      case QuestionType.single:
        final options = _optionControllers
            .map((controller) => controller.text.trim())
            .where((text) => text.isNotEmpty)
            .toList();
        if (options.length < 2) return;
        Navigator.pop(
          context,
          _block.copyWith(
            body: body,
            options: options,
            correct: {'index': _correctIndex.clamp(0, options.length - 1)},
          ),
        );
      case QuestionType.trueFalse:
        Navigator.pop(
          context,
          _block.copyWith(body: body, options: null, correct: {'value': _trueFalseValue}),
        );
      case QuestionType.fill:
        final answers = _fillController.text
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
        if (answers.isEmpty) return;
        Navigator.pop(
          context,
          _block.copyWith(body: body, options: null, correct: {'answers': answers}),
        );
      case QuestionType.order:
        final items = _optionControllers
            .map((controller) => controller.text.trim())
            .where((text) => text.isNotEmpty)
            .toList();
        if (items.length < 2) return;
        // Authored in the right order, so the answer is simply 0..n-1 --
        // the pupil's app shuffles them for display.
        Navigator.pop(
          context,
          _block.copyWith(
            body: body,
            options: items,
            correct: {'order': List<int>.generate(items.length, (i) => i)},
          ),
        );
      case QuestionType.match:
        final left = _leftControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
        final right = _rightControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
        if (left.isEmpty || left.length != right.length) return;
        // Row i on the left pairs with row i on the right as authored.
        Navigator.pop(
          context,
          _block.copyWith(
            body: body,
            options: {'left': left, 'right': right},
            correct: {'pairs': [for (var i = 0; i < left.length; i++) [i, i]]},
          ),
        );
      case null:
        Navigator.pop(context, _block.copyWith(body: body));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPage = _block.blockType == BlockType.page;

    return AppShell(
      title: isPage ? l10n.materialPage : l10n.materialQuestion,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: (const EdgeInsets.fromLTRB(16, 12, 16, 24)).add(bottomNavPadding(context)),
              children: [
                AppCard(
                  child: TextField(
                    controller: _bodyController,
                    maxLines: isPage ? 12 : 4,
                    minLines: isPage ? 6 : 2,
                    decoration: InputDecoration(
                      labelText: isPage ? l10n.materialPageText : l10n.materialQuestionText,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!isPage) ..._answerEditor(l10n),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _done, child: Text(l10n.save)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _answerEditor(AppLocalizations l10n) {
    final colors = context.colors;

    switch (_block.questionType) {
      case QuestionType.single:
        return [
          Text(l10n.materialMarkCorrect,
              style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 8),
          for (var i = 0; i < _optionControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _correctIndex == i
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: _correctIndex == i ? colors.success : colors.textMuted,
                    ),
                    onPressed: () => setState(() => _correctIndex = i),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _optionControllers[i],
                      decoration: InputDecoration(
                        hintText: '${l10n.materialOption} ${i + 1}',
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_optionControllers.length > 2)
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: colors.danger),
                      onPressed: () => setState(() {
                        _optionControllers.removeAt(i).dispose();
                        if (_correctIndex >= _optionControllers.length) {
                          _correctIndex = _optionControllers.length - 1;
                        }
                      }),
                    ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _optionControllers.add(TextEditingController())),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.materialAddOption),
          ),
        ];

      case QuestionType.trueFalse:
        return [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(l10n.materialTrue)),
              ButtonSegment(value: false, label: Text(l10n.materialFalse)),
            ],
            selected: {_trueFalseValue},
            onSelectionChanged: (values) => setState(() => _trueFalseValue = values.first),
          ),
        ];

      case QuestionType.fill:
        return [
          Text(l10n.materialAcceptedHint,
              style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 8),
          AppCard(
            child: TextField(
              controller: _fillController,
              maxLines: 5,
              minLines: 2,
              decoration: InputDecoration(
                labelText: l10n.materialAcceptedAnswers,
                border: InputBorder.none,
              ),
            ),
          ),
        ];

      case QuestionType.order:
        return [
          Text(l10n.materialOrderHint,
              style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 8),
          for (var i = 0; i < _optionControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}.',
                        style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _optionControllers[i],
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                  if (_optionControllers.length > 2)
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: colors.danger),
                      onPressed: () =>
                          setState(() => _optionControllers.removeAt(i).dispose()),
                    ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _optionControllers.add(TextEditingController())),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.materialAddOption),
          ),
        ];

      case QuestionType.match:
        return [
          Text(l10n.assignmentMatchHint,
              style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 8),
          for (var i = 0; i < _leftControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _leftControllers[i],
                      decoration: InputDecoration(hintText: l10n.materialLeftItem, isDense: true),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.link_rounded, size: 16),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _rightControllers[i],
                      decoration: InputDecoration(hintText: l10n.materialRightItem, isDense: true),
                    ),
                  ),
                  if (_leftControllers.length > 1)
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: colors.danger),
                      onPressed: () => setState(() {
                        _leftControllers.removeAt(i).dispose();
                        _rightControllers.removeAt(i).dispose();
                      }),
                    ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () => setState(() {
              _leftControllers.add(TextEditingController());
              _rightControllers.add(TextEditingController());
            }),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.materialAddOption),
          ),
        ];

      case null:
        return const [];
    }
  }
}
