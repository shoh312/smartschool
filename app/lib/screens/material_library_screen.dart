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
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/empty_state.dart';
import 'ai_material_screen.dart';
import 'material_editor_screen.dart';
import 'material_results_screen.dart';

/// The materials shelf: what you have written, what the school has
/// written, and what your classes are doing with it right now.
///
/// Three sections because they answer three different questions, ordered
/// by how time-sensitive they are: handouts in progress first, then your
/// own library, then colleagues' work you can read and copy.
///
/// A director gets a cut-down version of the same screen -- every class's
/// handouts and the whole school's materials, with nothing to author or
/// hand out, since every write endpoint behind it needs a teacher token.
class MaterialLibraryScreen extends StatefulWidget {
  const MaterialLibraryScreen({super.key});

  @override
  State<MaterialLibraryScreen> createState() => _MaterialLibraryScreenState();
}

class _MaterialLibraryScreenState extends State<MaterialLibraryScreen> {
  List<LearningMaterial> _mine = [];
  List<LearningMaterial> _school = [];
  List<MaterialAssignment> _assignments = [];
  bool _loading = true;
  String? _error;

  /// A director has no materials of their own -- they watch what the
  /// teachers are setting, and can't author or hand out anything.
  bool get _isDirector => context.read<AuthProvider>().role == AppRole.director;

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
    final service = context.read<MaterialService>();
    final myTeacherId = context.read<AuthProvider>().teacherId;
    try {
      // One school-wide call rather than two: "mine" is just this list
      // filtered by author, and asking twice would show a colleague's new
      // material in one section a refresh before the other.
      final all = await service.fetchLibrary(schoolWide: true);
      final assignments = await service.fetchAssignments();
      if (!mounted) return;
      setState(() {
        _mine = myTeacherId == null
            ? const []
            : all.where((m) => m.teacherId == myTeacherId).toList();
        _school = myTeacherId == null
            ? all
            : all.where((m) => m.teacherId != myTeacherId).toList();
        _assignments = assignments;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor([LearningMaterial? material]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialEditorScreen(materialId: material?.id),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _openResults(MaterialAssignment assignment) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialResultsScreen(assignmentId: assignment.id),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.materialsTitle,
      child: _loading
          ? const AppLoadingIndicator()
          : _error != null
              ? Center(child: Text(l10n.errorPrefix(_error!)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: (const EdgeInsets.fromLTRB(16, 12, 16, 32)).add(bottomNavPadding(context)),
                    children: [
                      if (!_isDirector) ...[
                        _NewMaterialButton(onTap: () => _openEditor()),
                        const SizedBox(height: 10),
                        _AiButton(
                          onTap: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => const AiMaterialScreen()),
                            );
                            if (changed == true) _load();
                          },
                        ),
                      ],
                      if (_assignments.isNotEmpty) ...[
                        if (!_isDirector) const SizedBox(height: 24),
                        DashboardSectionHeader(title: l10n.materialHandedOut),
                        for (final assignment in _assignments)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AssignmentRow(
                              assignment: assignment,
                              onTap: () => _openResults(assignment),
                            ),
                          ),
                      ],
                      if (!_isDirector) ...[
                        const SizedBox(height: 24),
                        DashboardSectionHeader(title: l10n.materialScopeMine),
                        if (_mine.isEmpty)
                          EmptyState(
                            icon: Icons.auto_stories_outlined,
                            title: l10n.materialEmptyTitle,
                            message: l10n.materialEmptyMessage,
                          )
                        else
                          for (final material in _mine)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _MaterialRow(
                                material: material,
                                // No author line: everything here is yours.
                                showAuthor: false,
                                onTap: () => _openEditor(material),
                              ),
                            ),
                      ],
                      const SizedBox(height: 24),
                      // "School", not "My library", for a director too: none
                      // of it is theirs, and calling it theirs implied an
                      // authorship (and an edit right) they don't have.
                      DashboardSectionHeader(title: l10n.materialScopeSchool),
                      if (_school.isEmpty)
                        EmptyState(
                          icon: Icons.groups_2_outlined,
                          title: l10n.materialEmptyTitle,
                          message: l10n.materialSchoolEmpty,
                        )
                      else
                        for (final material in _school)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _MaterialRow(
                              material: material,
                              showAuthor: true,
                              onTap: () => _openEditor(material),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}

class _AiButton extends StatelessWidget {
  const _AiButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: colors.primary.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: colors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.aiSubtitle,
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.material,
    required this.showAuthor,
    required this.onTap,
  });

  final LearningMaterial material;

  /// Whose it is, shown only where it isn't obvious -- naming yourself on
  /// every row of your own shelf is noise.
  final bool showAuthor;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    final facts = [
      material.subject,
      material.questionCount == 0
          ? l10n.materialNoQuestions
          : l10n.materialQuestionsCount(material.questionCount),
      if (material.assignedClassCount > 0)
        '${material.assignedClassCount} ${l10n.classes.toLowerCase()}',
    ].join(' · ');

    return AppListCard(
      title: material.title,
      subtitle: showAuthor && material.teacherName != null
          ? '${l10n.materialByTeacher(material.teacherName!)}\n$facts'
          : facts,
      subtitleMaxLines: showAuthor ? 2 : 1,
      leading: Icon(
        showAuthor ? Icons.groups_2_rounded : Icons.menu_book_rounded,
        color: showAuthor ? colors.info : colors.primary,
        size: 22,
      ),
      onTap: onTap,
    );
  }
}

class _NewMaterialButton extends StatelessWidget {
  const _NewMaterialButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: AppRadius.lgRadius,
          ),
          child: Row(
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.materialNew,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.materialsSubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
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

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({required this.assignment, required this.onTap});

  final MaterialAssignment assignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    // The one number a teacher actually scans this list for: how many of
    // the class are still to hand it in.
    final done = assignment.submittedCount;
    final total = assignment.studentCount;
    final complete = total > 0 && done >= total;

    return AppListCard(
      title: assignment.materialTitle,
      subtitle: [
        assignment.className ?? '',
        assignment.isControl ? l10n.materialModeControl : l10n.materialModePractice,
        l10n.materialSubmittedOf(done, total),
      ].where((part) => part.isNotEmpty).join(' · '),
      leading: Icon(
        assignment.isControl ? Icons.fact_check_rounded : Icons.fitness_center_rounded,
        color: assignment.isControl ? colors.warning : colors.info,
        size: 22,
      ),
      trailing: AppListBadge(
        text: '$done/$total',
        color: complete ? colors.success : colors.textMuted,
      ),
      onTap: onTap,
    );
  }
}
