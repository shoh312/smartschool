import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/material.dart';
import '../services/material_service.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/material/material_block_widgets.dart';
import 'material_editor_screen.dart';

/// Where a lesson can start from.
enum _Source { topic, photo, text }

/// Drafting material with AI, one step at a time.
///
/// A wizard rather than one long form because the three sources need
/// different inputs, and because the last step is the important one: what
/// the model wrote is a draft, and the teacher reads and fixes it before
/// any of it is saved. Nothing here writes to the library -- the final
/// button hands the blocks to the ordinary create-material call.
class AiMaterialScreen extends StatefulWidget {
  const AiMaterialScreen({super.key});

  @override
  State<AiMaterialScreen> createState() => _AiMaterialScreenState();
}

class _AiMaterialScreenState extends State<AiMaterialScreen> {
  int _step = 0;

  _Source _source = _Source.topic;
  final _topicController = TextEditingController();
  final _textController = TextEditingController();
  String? _imagePath;

  bool _testOnly = false;
  int _questionCount = 8;
  int _pageCount = 3;
  String _difficulty = 'medium';
  final Set<QuestionType> _types = {QuestionType.single, QuestionType.trueFalse};

  bool _working = false;
  String? _error;
  AiDraft? _draft;
  List<MaterialBlock> _blocks = [];

  @override
  void dispose() {
    _topicController.dispose();
    _textController.dispose();
    super.dispose();
  }

  bool get _hasSource => switch (_source) {
        _Source.topic => _topicController.text.trim().isNotEmpty,
        _Source.photo => _imagePath != null,
        _Source.text => _textController.text.trim().length > 20,
      };

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked != null && mounted) setState(() => _imagePath = picked.path);
  }

  Future<void> _generate() async {
    final l10n = AppLocalizations.of(context)!;
    if (_types.isEmpty) {
      _toast(l10n.aiNeedTypes);
      return;
    }

    setState(() {
      _working = true;
      _error = null;
      _step = 2;
    });

    final service = context.read<MaterialService>();
    try {
      final draft = await service.generateWithAi(
        testOnly: _testOnly,
        topic: _source == _Source.topic ? _topicController.text.trim() : null,
        sourceText: _source == _Source.text ? _textController.text.trim() : null,
        imagePath: _source == _Source.photo ? _imagePath : null,
        questionCount: _questionCount,
        pageCount: _testOnly ? 0 : _pageCount,
        questionTypes: _types.toList(),
        difficulty: _difficulty,
      );
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _blocks = List.of(draft.blocks);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _blocks.isEmpty) return;

    setState(() => _working = true);
    final service = context.read<MaterialService>();
    try {
      final created = await service.createMaterial(
        title: draft.title.isEmpty ? _topicController.text.trim() : draft.title,
        description: draft.description,
        blocks: _blocks,
      );
      if (!mounted) return;
      // Straight into the normal editor: from here on it is an ordinary
      // material, with the same edit and hand-out flow as a hand-written one.
      //
      // push, never pushReplacement. This screen is one of the teacher's
      // bottom-bar tabs, so replacing "the current route" replaces the
      // whole tabbed shell -- and the editor's own Save then pops the only
      // route left, leaving a black window with nothing under it.
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MaterialEditorScreen(materialId: created.id)),
      );
      if (!mounted) return;
      // Back at the wizard: clear the finished draft so it starts fresh
      // rather than offering to save the same material a second time.
      setState(() {
        _step = 0;
        _draft = null;
        _blocks = [];
        _error = null;
        _topicController.clear();
        _textController.clear();
        _imagePath = null;
      });
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.aiTitle,
      child: Column(
        children: [
          _StepBar(
            step: _step,
            labels: [l10n.aiStepSource, l10n.aiStepSettings, l10n.aiStepReview],
          ),
          Expanded(
            child: switch (_step) {
              0 => _buildSourceStep(l10n),
              1 => _buildSettingsStep(l10n),
              _ => _buildReviewStep(l10n),
            },
          ),
          _buildActions(l10n),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Step 1 -- where the lesson comes from
  // ------------------------------------------------------------------

  Widget _buildSourceStep(AppLocalizations l10n) {
    final colors = context.colors;
    return ListView(
      padding: (const EdgeInsets.fromLTRB(16, 8, 16, 16)).add(bottomNavPadding(context)),
      children: [
        Text(
          l10n.aiSubtitle,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        const SizedBox(height: 16),
        _SourceTile(
          icon: Icons.edit_note_rounded,
          label: l10n.aiSourceTopic,
          hint: l10n.aiSourceTopicHint,
          selected: _source == _Source.topic,
          onTap: () => setState(() => _source = _Source.topic),
        ),
        if (_source == _Source.topic) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _topicController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.aiSourceTopicHint,
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 10),
        _SourceTile(
          icon: Icons.photo_camera_rounded,
          label: l10n.aiSourcePhoto,
          hint: l10n.aiSourcePhotoHint,
          selected: _source == _Source.photo,
          onTap: () => setState(() => _source = _Source.photo),
        ),
        if (_source == _Source.photo) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(_imagePath == null ? l10n.aiPickPhoto : l10n.aiPhotoReady),
          ),
        ],
        const SizedBox(height: 10),
        _SourceTile(
          icon: Icons.content_paste_rounded,
          label: l10n.aiSourceText,
          hint: l10n.aiSourceTextHint,
          selected: _source == _Source.text,
          onTap: () => setState(() => _source = _Source.text),
        ),
        if (_source == _Source.text) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _textController,
            maxLines: 10,
            minLines: 5,
            decoration: InputDecoration(
              hintText: l10n.aiSourceTextHint,
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------
  // Step 2 -- what to build
  // ------------------------------------------------------------------

  Widget _buildSettingsStep(AppLocalizations l10n) {
    final colors = context.colors;
    final typeLabels = {
      QuestionType.single: l10n.materialTypeSingle,
      QuestionType.trueFalse: l10n.materialTypeTrueFalse,
      QuestionType.fill: l10n.materialTypeFill,
      QuestionType.order: l10n.materialTypeOrder,
      QuestionType.match: l10n.materialTypeMatch,
    };

    return ListView(
      padding: (const EdgeInsets.fromLTRB(16, 8, 16, 16)).add(bottomNavPadding(context)),
      children: [
        _Label(l10n.materialMode),
        Row(
          children: [
            Expanded(
              child: _Choice(
                label: l10n.materialModePractice,
                selected: !_testOnly,
                onTap: () => setState(() => _testOnly = false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Choice(
                label: l10n.materialModeControl,
                selected: _testOnly,
                onTap: () => setState(() => _testOnly = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Label('${l10n.aiQuestionCount}: $_questionCount'),
        Slider(
          value: _questionCount.toDouble(),
          min: 3,
          max: 20,
          divisions: 17,
          label: '$_questionCount',
          onChanged: (v) => setState(() => _questionCount = v.round()),
        ),
        if (!_testOnly) ...[
          _Label('${l10n.aiPageCount}: $_pageCount'),
          Slider(
            value: _pageCount.toDouble(),
            min: 1,
            max: 8,
            divisions: 7,
            label: '$_pageCount',
            onChanged: (v) => setState(() => _pageCount = v.round()),
          ),
        ],
        const SizedBox(height: 12),
        _Label(l10n.materialQuestionType),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in typeLabels.entries)
              FilterChip(
                label: Text(entry.value),
                selected: _types.contains(entry.key),
                onSelected: (on) => setState(() {
                  if (on) {
                    _types.add(entry.key);
                  } else {
                    _types.remove(entry.key);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _Label(l10n.aiDifficulty),
        Row(
          children: [
            for (final entry in {
              'easy': l10n.aiDifficultyEasy,
              'medium': l10n.aiDifficultyMedium,
              'hard': l10n.aiDifficultyHard,
            }.entries) ...[
              Expanded(
                child: _Choice(
                  label: entry.value,
                  selected: _difficulty == entry.key,
                  onTap: () => setState(() => _difficulty = entry.key),
                ),
              ),
              if (entry.key != 'hard') const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Text(
          l10n.aiWorkingHint,
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Step 3 -- read it before anyone else does
  // ------------------------------------------------------------------

  Widget _buildReviewStep(AppLocalizations l10n) {
    final colors = context.colors;

    if (_working) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              l10n.aiWorking,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.aiWorkingHint,
              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.errorPrefix(_error!),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }

    return ListView(
      padding: (const EdgeInsets.fromLTRB(16, 8, 16, 16)).add(bottomNavPadding(context)),
      children: [
        // Not a soft "note" -- the whole reason this step exists.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.10),
            borderRadius: AppRadius.mdRadius,
            border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: colors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.aiReviewWarning,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        if ((_draft?.droppedCount ?? 0) > 0) ...[
          const SizedBox(height: 10),
          Text(
            l10n.aiDropped(_draft!.droppedCount),
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
        ],
        const SizedBox(height: 16),
        if (_draft != null && _draft!.title.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _draft!.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                if (_draft!.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _draft!.description!,
                    style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        for (var i = 0; i < _blocks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MaterialBlockRow(
              block: _blocks[i],
              index: i,
              onTap: () async {
                final edited = await editMaterialBlock(context, _blocks[i]);
                if (edited != null) setState(() => _blocks[i] = edited);
              },
              onRemove: () => setState(() => _blocks.removeAt(i)),
              onMoveUp: i == 0
                  ? null
                  : () => setState(() {
                        final block = _blocks.removeAt(i);
                        _blocks.insert(i - 1, block);
                      }),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------

  Widget _buildActions(AppLocalizations l10n) {
    final onReview = _step == 2;
    final canSave = onReview && !_working && _error == null && _blocks.isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _working
                      ? null
                      : () => setState(() => _step = onReview ? 1 : _step - 1),
                  child: Text(onReview ? l10n.aiRegenerate : l10n.aiBack),
                ),
              ),
            if (_step > 0) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: switch (_step) {
                  0 => _hasSource ? () => setState(() => _step = 1) : null,
                  1 => _working ? null : _generate,
                  _ => canSave ? _save : null,
                },
                child: Text(switch (_step) {
                  0 => l10n.aiNext,
                  1 => l10n.aiGenerate,
                  _ => l10n.aiSaveMaterial,
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Pieces
// --------------------------------------------------------------------------

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step ? colors.primary : colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                      color: i <= step ? colors.textPrimary : colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (i != labels.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
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
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: context.colors.textSecondary,
          ),
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.primary.withValues(alpha: 0.10) : colors.surface,
            borderRadius: AppRadius.mdRadius,
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
