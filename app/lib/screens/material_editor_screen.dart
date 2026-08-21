import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/app_role.dart';
import '../models/material.dart';
import '../providers/auth_provider.dart';
import '../services/material_service.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/material/material_block_widgets.dart';
import '../widgets/bottom_nav_inset.dart';
import 'material_assign_screen.dart';

/// Writing a lesson: an ordered run of explanation pages and questions.
///
/// The blocks are edited in memory and saved in one go. That's deliberate --
/// a half-saved material with three of its five questions would be handed
/// to a class in that state.
class MaterialEditorScreen extends StatefulWidget {
  const MaterialEditorScreen({super.key, this.materialId});

  /// Null when writing something new.
  final int? materialId;

  @override
  State<MaterialEditorScreen> createState() => _MaterialEditorScreenState();
}

class _MaterialEditorScreenState extends State<MaterialEditorScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<MaterialBlock> _blocks = [];

  bool _loading = false;
  bool _saving = false;
  String? _error;
  LearningMaterial? _existing;

  /// Somebody else's work, or a director looking: everything is read-only
  /// and the only way to act on it is to take a copy.
  bool get _foreign {
    final material = _existing;
    if (material == null) return false;
    final auth = context.read<AuthProvider>();
    return auth.role != AppRole.teacher || material.teacherId != auth.teacherId;
  }

  /// True once it's been handed to a class: the questions are frozen from
  /// then on, because pupils may be part-way through answering them. A
  /// colleague's material is locked for the stronger reason above.
  bool get _locked => _foreign || (_existing?.assignedClassCount ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    if (widget.materialId != null) _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final material = await context.read<MaterialService>().fetchMaterial(widget.materialId!);
      if (!mounted) return;
      setState(() {
        _existing = material;
        _titleController.text = material.title;
        _descriptionController.text = material.description ?? '';
        _blocks = List.of(material.blocks);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_titleController.text.trim().isEmpty) {
      _toast(l10n.materialTitleLabel);
      return;
    }
    if (_blocks.isEmpty) {
      _toast(l10n.materialContentEmpty);
      return;
    }

    setState(() => _saving = true);
    final service = context.read<MaterialService>();
    try {
      if (_existing == null) {
        final created = await service.createMaterial(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          blocks: _blocks,
        );
        if (!mounted) return;
        setState(() => _existing = created);
      } else {
        await service.updateMaterial(
          _existing!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          // Sending the block list at all is what the server refuses once
          // the material is out there, so a locked material saves only its
          // title and description.
          blocks: _locked ? null : _blocks,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------------
  // Block editing
  // ------------------------------------------------------------------

  Future<void> _addPage() async {
    final block = await _editBlock(const MaterialBlock(blockType: BlockType.page));
    if (block != null) setState(() => _blocks.add(block));
  }

  Future<void> _addQuestion() async {
    final type = await _pickQuestionType();
    if (type == null) return;
    final block = await _editBlock(
      MaterialBlock(
        blockType: BlockType.question,
        questionType: type,
        options: type == QuestionType.single
            ? <String>['', '']
            : type == QuestionType.order
                ? <String>['', '']
                : type == QuestionType.match
                    ? {'left': <String>[''], 'right': <String>['']}
                    : null,
        correct: _defaultCorrect(type),
      ),
    );
    if (block != null) setState(() => _blocks.add(block));
  }

  static dynamic _defaultCorrect(QuestionType type) {
    switch (type) {
      case QuestionType.single:
        return {'index': 0};
      case QuestionType.trueFalse:
        return {'value': true};
      case QuestionType.fill:
        return {'answers': <String>[]};
      case QuestionType.match:
        return {'pairs': <List<int>>[]};
      case QuestionType.order:
        return {'order': <int>[]};
    }
  }

  Future<QuestionType?> _pickQuestionType() {
    final l10n = AppLocalizations.of(context)!;
    final labels = {
      QuestionType.single: l10n.materialTypeSingle,
      QuestionType.trueFalse: l10n.materialTypeTrueFalse,
      QuestionType.fill: l10n.materialTypeFill,
      QuestionType.order: l10n.materialTypeOrder,
      QuestionType.match: l10n.materialTypeMatch,
    };
    return showModalBottomSheet<QuestionType>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              l10n.materialQuestionType,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in labels.entries)
              ListTile(
                title: Text(entry.value),
                onTap: () => Navigator.pop(sheetContext, entry.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<MaterialBlock?> _editBlock(MaterialBlock block) =>
      editMaterialBlock(context, block);

  Future<void> _pasteImport() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(l10n.materialPasteTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.materialPasteHelp,
                style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 10,
                minLines: 6,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(l10n.materialPasteAction),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;

    final service = context.read<MaterialService>();
    try {
      final parsed = await service.parsePaste(text);
      if (!mounted) return;
      setState(() => _blocks.addAll(parsed));
      _toast(l10n.materialPasteResult(parsed.length));
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  Future<void> _assign() async {
    final material = _existing;
    if (material == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialAssignScreen(material: material),
      ),
    );
    if (changed == true && mounted) Navigator.pop(context, true);
  }

  /// Only a teacher has a library to copy into.
  bool get _canCopy => context.read<AuthProvider>().role == AppRole.teacher;

  Future<void> _duplicate() async {
    try {
      final copy = await context.read<MaterialService>().duplicateMaterial(_existing!.id);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MaterialEditorScreen(materialId: copy.id)),
      );
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(l10n.materialDeleteTitle),
        content: Text(l10n.materialDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final service = context.read<MaterialService>();
    try {
      await service.deleteMaterial(_existing!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return AppShell(
      title: _existing?.title.isNotEmpty == true ? _existing!.title : l10n.materialNew,
      actions: [
        if (_existing != null && !_foreign)
          IconButton(
            tooltip: l10n.delete,
            icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
            onPressed: _delete,
          ),
      ],
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
                          AppCard(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _titleController,
                                  // Read-only where the material isn't
                                  // yours: an editable-looking box you
                                  // can type in but never save is worse
                                  // than one that plainly won't budge.
                                  enabled: !_foreign,
                                  decoration: InputDecoration(
                                    labelText: l10n.materialTitleLabel,
                                    border: InputBorder.none,
                                    // Borderless fields stacked directly on
                                    // each other left the second one's label
                                    // sitting on the first one's text; these
                                    // two, plus the divider below, keep them
                                    // apart.
                                    isDense: true,
                                    contentPadding: const EdgeInsets.only(bottom: 10),
                                  ),
                                ),
                                Divider(height: 20, color: colors.border),
                                TextField(
                                  controller: _descriptionController,
                                  enabled: !_foreign,
                                  maxLines: 2,
                                  minLines: 1,
                                  decoration: InputDecoration(
                                    labelText: l10n.materialDescriptionLabel,
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.only(top: 4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_locked) ...[
                            const SizedBox(height: 12),
                            _Notice(
                              text: _foreign ? l10n.materialReadOnly : l10n.materialLockedEdit,
                              // A director has no library to copy into.
                              onAction: _canCopy ? _duplicate : null,
                              actionLabel: _canCopy ? l10n.materialDuplicate : null,
                            ),
                          ],
                          const SizedBox(height: 16),
                          for (var i = 0; i < _blocks.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: MaterialBlockRow(
                                block: _blocks[i],
                                index: i,
                                locked: _locked,
                                onTap: _locked
                                    ? null
                                    : () async {
                                        final edited = await _editBlock(_blocks[i]);
                                        if (edited != null) setState(() => _blocks[i] = edited);
                                      },
                                onRemove: _locked ? null : () => setState(() => _blocks.removeAt(i)),
                                onMoveUp: _locked || i == 0
                                    ? null
                                    : () => setState(() {
                                          final block = _blocks.removeAt(i);
                                          _blocks.insert(i - 1, block);
                                        }),
                              ),
                            ),
                          if (!_locked) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _addPage,
                                    icon: const Icon(Icons.article_outlined, size: 18),
                                    label: Text(l10n.materialAddPage),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _addQuestion,
                                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                                    label: Text(l10n.materialAddQuestion),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _pasteImport,
                              icon: const Icon(Icons.content_paste_rounded, size: 18),
                              label: Text(l10n.materialPasteImport),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: _foreign
                            ? SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  // The only action on a colleague's work:
                                  // take it into your own library and make
                                  // it yours.
                                  onPressed: _canCopy ? _duplicate : null,
                                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                                  label: Text(l10n.materialDuplicate),
                                ),
                              )
                            : Row(
                                children: [
                                  if (_existing != null) ...[
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _assign,
                                        icon: const Icon(Icons.send_rounded, size: 18),
                                        label: Text(l10n.materialAssign),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _saving ? null : _save,
                                      child: Text(l10n.save),
                                    ),
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

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.onAction, this.actionLabel});

  final String text;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.10),
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: colors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
          ),
          if (onAction != null && actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
