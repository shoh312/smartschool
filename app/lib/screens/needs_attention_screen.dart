import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/analytics.dart';
import '../providers/school_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import 'student_analytics_screen.dart';

/// Two lists for a director/teacher to act on: the lowest overall averages,
/// and the students whose average dropped the most since last quarter --
/// the low end of the same data [RankingListScreen] shows, surfaced
/// separately instead of making them scroll a whole leaderboard.
class NeedsAttentionScreen extends StatefulWidget {
  const NeedsAttentionScreen({super.key, required this.scope, required this.title, this.scopeId});

  final RankingScope scope;
  final String title;
  final int? scopeId;

  @override
  State<NeedsAttentionScreen> createState() => _NeedsAttentionScreenState();
}

class _NeedsAttentionScreenState extends State<NeedsAttentionScreen> {
  NeedsAttentionResult? _result;
  bool _loading = true;
  String? _error;

  /// null = the whole scope this screen was opened for. Picking a class
  /// narrows the lists to it: a school-wide list of names is unusable once
  /// there are more pupils than staff can recognise, so the class filter is
  /// how a director actually gets to an actionable shortlist.
  int? _classFilter;

  @override
  void initState() {
    super.initState();
    final school = context.read<SchoolProvider>();
    if (school.classes.isEmpty) school.loadSchoolData();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = context.read<AnalyticsService>();
      final result = _classFilter == null
          ? await service.needsAttention(scope: widget.scope, scopeId: widget.scopeId)
          : await service.needsAttention(
              scope: RankingScope.classScope,
              scopeId: _classFilter,
            );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectClass(int? classId) {
    if (classId == _classFilter) return;
    setState(() => _classFilter = classId);
    _load();
  }

  void _openStudent(int studentId, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StudentAnalyticsScreen(studentId: studentId, studentName: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = _result;
    final isEmpty = result == null || (result.bottomPerformers.isEmpty && result.biggestDecliners.isEmpty);

    final classes = context.watch<SchoolProvider>().classes;

    return AppShell(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (classes.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                itemCount: classes.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final id = isAll ? null : classes[index - 1].id;
                  return ChoiceChip(
                    label: Text(isAll ? l10n.rankingScopeAll : classes[index - 1].name),
                    selected: id == _classFilter,
                    onSelected: (_) => _selectClass(id),
                  );
                },
              ),
            ),
          Expanded(
            child: _loading
                ? const AppLoadingIndicator()
                : _error != null
                    ? Center(child: Text(l10n.errorPrefix(_error!)))
                    : isEmpty
                        ? EmptyState(
                            icon: Icons.check_circle_outline_rounded,
                            title: l10n.noDataTitle,
                            message: l10n.noGradesYetMessage,
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                        padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
                        children: [
                          if (result.biggestDecliners.isNotEmpty) ...[
                            DashboardSectionHeader(title: l10n.biggestDecline),
                            for (final entry in result.biggestDecliners.asMap().entries)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: FadeSlideIn(
                                  delay: Duration(milliseconds: 30 * entry.key.clamp(0, 12)),
                                  child: _DeclinerTile(
                                    entry: entry.value,
                                    onTap: () => _openStudent(entry.value.studentId, entry.value.fullName),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                          ],
                          if (result.bottomPerformers.isNotEmpty) ...[
                            DashboardSectionHeader(title: l10n.lowestAverage),
                            for (final entry in result.bottomPerformers.asMap().entries)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: FadeSlideIn(
                                  delay: Duration(milliseconds: 30 * entry.key.clamp(0, 12)),
                                  child: _BottomPerformerTile(
                                    entry: entry.value,
                                    onTap: () => _openStudent(entry.value.studentId, entry.value.fullName),
                                  ),
                                ),
                              ),
                          ],
                        ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _DeclinerTile extends StatelessWidget {
  const _DeclinerTile({required this.entry, required this.onTap});

  final DeclinerEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppGradients.tint(context.colors.danger),
                  borderRadius: AppRadius.smRadius,
                ),
                child: Icon(Icons.trending_down_rounded, color: context.colors.danger, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.className == null
                          ? entry.fullName
                          : '${entry.fullName} · ${entry.className}',
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${entry.previousAverage.toStringAsFixed(2)} → ${entry.currentAverage.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 11.5, color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                entry.delta.toStringAsFixed(2),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: context.colors.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomPerformerTile extends StatelessWidget {
  const _BottomPerformerTile({required this.entry, required this.onTap});

  final LeaderboardEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppGradients.tint(context.colors.warning),
                  borderRadius: AppRadius.smRadius,
                ),
                child: Icon(Icons.south_rounded, color: context.colors.warning, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.className == null
                          ? entry.fullName
                          : '${entry.fullName} · ${entry.className}',
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      l10n.overallAverage,
                      style: TextStyle(fontSize: 11.5, color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                entry.overallAverage == null ? '—' : entry.overallAverage!.toStringAsFixed(2),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: context.colors.warning),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
