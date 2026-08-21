import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/analytics.dart';
import '../models/school_class.dart';
import '../providers/school_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/empty_state.dart';
import 'student_analytics_screen.dart';

enum _ScopeFilter { all, classes, parallel }

/// A leaderboard for one ranking scope (class, parallel, or whole school) --
/// tapping a row opens that student's full [StudentAnalyticsScreen]. The
/// scope itself is switchable in-screen via a top filter (All / Classes /
/// Parallel) instead of needing a separate entry point per scope, and the
/// top 3 are pulled out into their own podium block above the rest of the
/// list.
class RankingListScreen extends StatefulWidget {
  const RankingListScreen({
    super.key,
    required this.scope,
    required this.title,
    this.scopeId,
  });

  final RankingScope scope;
  final String title;
  final int? scopeId;

  @override
  State<RankingListScreen> createState() => _RankingListScreenState();
}

class _RankingListScreenState extends State<RankingListScreen> {
  List<LeaderboardEntry>? _entries;
  bool _loading = true;
  bool _needsSelection = false;
  String? _error;

  late _ScopeFilter _filter;
  int? _selectedClassId;
  int? _selectedGrade;

  @override
  void initState() {
    super.initState();
    switch (widget.scope) {
      case RankingScope.classScope:
        _filter = _ScopeFilter.classes;
        _selectedClassId = widget.scopeId;
        break;
      case RankingScope.parallel:
        _filter = _ScopeFilter.parallel;
        _selectedGrade = widget.scopeId;
        break;
      case RankingScope.school:
        _filter = _ScopeFilter.all;
        break;
    }
    final school = context.read<SchoolProvider>();
    if (school.classes.isEmpty) {
      school.loadSchoolData();
    }
    _load();
  }

  RankingScope get _effectiveScope => switch (_filter) {
        _ScopeFilter.all => RankingScope.school,
        _ScopeFilter.classes => RankingScope.classScope,
        _ScopeFilter.parallel => RankingScope.parallel,
      };

  int? get _effectiveScopeId => switch (_filter) {
        _ScopeFilter.all => null,
        _ScopeFilter.classes => _selectedClassId,
        _ScopeFilter.parallel => _selectedGrade,
      };

  List<int> _sortedGrades(List<SchoolClass> classes) {
    final grades = classes.map((c) => c.grade).toSet().toList();
    grades.sort();
    return grades;
  }

  Future<void> _load() async {
    if (_filter != _ScopeFilter.all && _effectiveScopeId == null) {
      setState(() {
        _entries = [];
        _needsSelection = true;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _needsSelection = false;
      _error = null;
    });
    try {
      final service = context.read<AnalyticsService>();
      final entries = await service.ranking(scope: _effectiveScope, scopeId: _effectiveScopeId);
      if (mounted) setState(() => _entries = entries);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFilter(_ScopeFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      if (filter == _ScopeFilter.classes && _selectedClassId == null) {
        final classes = context.read<SchoolProvider>().classes;
        if (classes.isNotEmpty) _selectedClassId = classes.first.id;
      }
      if (filter == _ScopeFilter.parallel && _selectedGrade == null) {
        final grades = _sortedGrades(context.read<SchoolProvider>().classes);
        if (grades.isNotEmpty) _selectedGrade = grades.first;
      }
    });
    _load();
  }

  void _selectClass(int classId) {
    if (classId == _selectedClassId) return;
    setState(() => _selectedClassId = classId);
    _load();
  }

  void _selectGrade(int grade) {
    if (grade == _selectedGrade) return;
    setState(() => _selectedGrade = grade);
    _load();
  }

  /// What the summary card's numbers are actually about -- the whole school,
  /// one class, or one parallel. Shown on the card so a screenshot of it
  /// still says what it is once the filter bar has scrolled out of frame.
  String _scopeLabel(AppLocalizations l10n, List<SchoolClass> classes) {
    switch (_filter) {
      case _ScopeFilter.all:
        return l10n.schoolRanking;
      case _ScopeFilter.classes:
        final match = classes.where((c) => c.id == _selectedClassId);
        return match.isEmpty ? l10n.classRanking : match.first.name;
      case _ScopeFilter.parallel:
        return _selectedGrade == null
            ? l10n.parallelRanking
            : '${_selectedGrade!}-${l10n.parallelRank}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final classes = context.watch<SchoolProvider>().classes;
    final grades = _sortedGrades(classes);

    return AppShell(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _ScopeFilterBar(filter: _filter, onChanged: _setFilter),
          ),
          if (_filter == _ScopeFilter.classes && classes.isNotEmpty)
            _ChipPicker(
              items: [for (final c in classes) (c.id, c.name)],
              selected: _selectedClassId,
              onSelected: _selectClass,
            ),
          if (_filter == _ScopeFilter.parallel && grades.isNotEmpty)
            _ChipPicker(
              items: [for (final g in grades) (g, '$g')],
              selected: _selectedGrade,
              onSelected: _selectGrade,
            ),
          Expanded(
            child: _loading
                ? const AppLoadingIndicator()
                : _error != null
                    ? Center(child: Text(l10n.errorPrefix(_error!)))
                    : _entries == null || _entries!.isEmpty
                        ? EmptyState(
                            icon: Icons.leaderboard_outlined,
                            title: l10n.noDataTitle,
                            message: _needsSelection
                                ? (_filter == _ScopeFilter.classes
                                    ? l10n.selectClassPrompt
                                    : l10n.selectParallelPrompt)
                                : l10n.noGradesYetMessage,
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: _RankingBody(
                              entries: _entries!,
                              scopeLabel: _scopeLabel(l10n, classes),
                              onTapStudent: (entry) => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StudentAnalyticsScreen(
                                    studentId: entry.studentId,
                                    studentName: entry.fullName,
                                  ),
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ScopeFilterBar extends StatelessWidget {
  const _ScopeFilterBar({required this.filter, required this.onChanged});

  final _ScopeFilter filter;
  final ValueChanged<_ScopeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (_ScopeFilter.all, l10n.rankingScopeAll),
      (_ScopeFilter.classes, l10n.rankingScopeClasses),
      (_ScopeFilter.parallel, l10n.rankingScopeParallel),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(items[i].$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: items[i].$1 == filter ? AppGradients.primary : null,
                  color: items[i].$1 == filter ? null : context.colors.surface,
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(
                    color: items[i].$1 == filter ? Colors.transparent : context.colors.border,
                  ),
                ),
                child: Text(
                  items[i].$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: items[i].$1 == filter ? Colors.white : context.colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChipPicker extends StatelessWidget {
  const _ChipPicker({required this.items, required this.selected, required this.onSelected});

  final List<(int, String)> items;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (id, label) = items[index];
          final isSelected = id == selected;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onSelected(id),
            selectedColor: context.colors.primary,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : context.colors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
            backgroundColor: context.colors.surface,
            side: BorderSide(color: isSelected ? Colors.transparent : context.colors.border),
          );
        },
      ),
    );
  }
}

/// Podium block for positions 1-3 followed by a plain list for the rest --
/// pulling the top out into its own visual block instead of it just being
/// the first three rows of one long list.
class _RankingBody extends StatelessWidget {
  const _RankingBody({
    required this.entries,
    required this.scopeLabel,
    required this.onTapStudent,
  });

  final List<LeaderboardEntry> entries;
  final String scopeLabel;
  final ValueChanged<LeaderboardEntry> onTapStudent;

  @override
  Widget build(BuildContext context) {
    final top = entries.take(3).toList();
    final rest = entries.length > 3 ? entries.sublist(3) : const <LeaderboardEntry>[];

    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: (const EdgeInsets.only(top: 4, bottom: 16)).add(bottomNavPadding(context)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: FadeSlideIn(
            child: _ScopeSummaryCard(entries: entries, scopeLabel: scopeLabel),
          ),
        ),
        FadeSlideIn(
          delay: const Duration(milliseconds: 90),
          child: _PodiumBlock(entries: top, onTap: onTapStudent),
        ),
        if (rest.isNotEmpty && l10n != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: DashboardSectionHeader(title: l10n.ratingAnalytics),
          ),
        for (var i = 0; i < rest.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FadeSlideIn(
              delay: i < 12 ? Duration(milliseconds: 150 + 40 * i) : Duration.zero,
              child: _LeaderboardTile(entry: rest[i], onTap: () => onTapStudent(rest[i])),
            ),
          ),
      ],
    );
  }
}

/// The hero block: one big average for whatever scope is selected, plus how
/// that group splits into strong / middling / struggling.
///
/// Every number here is folded from the leaderboard rows already on screen,
/// so the card costs no extra request -- the same reason the pupil's rating
/// screen builds its daily series from marks it already has.
class _ScopeSummaryCard extends StatelessWidget {
  const _ScopeSummaryCard({required this.entries, required this.scopeLabel});

  final List<LeaderboardEntry> entries;
  final String scopeLabel;

  /// Matches the thresholds the per-subject bars use on the pupil's rating
  /// screen, so "green" means the same thing on both.
  static const _strongFrom = 8.0;
  static const _weakBelow = 6.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scored = entries.map((e) => e.overallAverage).whereType<double>().toList();
    final average = scored.isEmpty
        ? null
        : scored.reduce((a, b) => a + b) / scored.length;
    final strong = scored.where((v) => v >= _strongFrom).length;
    final weak = scored.where((v) => v < _weakBelow).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppShadows.colored(context.colors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.overallAverage,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: Text(
                    scopeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          average == null
              ? const Text(
                  '—',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 40,
                    height: 1.1,
                  ),
                )
              : AnimatedNumber(
                  value: average,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 40,
                    height: 1.1,
                  ),
                ),
          const SizedBox(height: 18),
          Row(
            children: [
              _SummaryStat(
                icon: Icons.groups_rounded,
                value: '${entries.length}',
                label: l10n.students,
              ),
              const SizedBox(width: 10),
              _SummaryStat(
                icon: Icons.workspace_premium_rounded,
                value: '$strong',
                label: l10n.ratingHighAchievers,
                tint: RankColors.gold,
              ),
              const SizedBox(width: 10),
              _SummaryStat(
                icon: Icons.warning_amber_rounded,
                value: '$weak',
                label: l10n.needsAttention,
                tint: weak > 0 ? const Color(0xFFFCA5A5) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.value,
    required this.label,
    this.tint,
  });

  final IconData icon;
  final String value;
  final String label;

  /// Null keeps the neutral translucent-white pill; a colour is only worth
  /// spending when the number means something (a medal, or a warning that
  /// actually has people in it).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: (tint ?? Colors.white).withOpacity(tint == null ? 0.16 : 0.26),
          borderRadius: AppRadius.mdRadius,
          border: tint == null ? null : Border.all(color: tint!.withOpacity(0.55)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: tint ?? Colors.white, size: 13),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumBlock extends StatelessWidget {
  const _PodiumBlock({required this.entries, required this.onTap});

  /// Up to 3 entries, already sorted by position.
  final List<LeaderboardEntry> entries;
  final ValueChanged<LeaderboardEntry> onTap;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: second == null
                ? const SizedBox.shrink()
                : _PodiumCard(entry: second, onTap: () => onTap(second)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: first == null
                ? const SizedBox.shrink()
                : _PodiumCard(entry: first, emphasize: true, onTap: () => onTap(first)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: third == null
                ? const SizedBox.shrink()
                : _PodiumCard(entry: third, onTap: () => onTap(third)),
          ),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.entry, required this.onTap, this.emphasize = false});

  final LeaderboardEntry entry;
  final bool emphasize;
  final VoidCallback onTap;

  static String _initials(String first, String last) {
    final a = first.isNotEmpty ? first[0] : '';
    final b = last.isNotEmpty ? last[0] : '';
    final result = ('$a$b').toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  @override
  Widget build(BuildContext context) {
    final medal = RankColors.forPosition(context, entry.position);
    final avatarSize = emphasize ? 56.0 : 42.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: emphasize ? 16 : 14),
          decoration: BoxDecoration(
            // The winner is the one thing on this screen worth a filled
            // card; 2nd and 3rd keep the app's plain surface with only a
            // medal-tinted edge, so the podium has a clear peak instead of
            // three tiles competing.
            gradient: emphasize
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF4D160), RankColors.gold],
                  )
                : null,
            color: emphasize ? null : context.colors.surface,
            borderRadius: AppRadius.lgRadius,
            border: emphasize ? null : Border.all(color: medal.withOpacity(0.45)),
            boxShadow: emphasize ? AppShadows.colored(RankColors.gold) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emphasize) ...[
                const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 24),
                const SizedBox(height: 6),
              ],
              Container(
                width: avatarSize,
                height: avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // On the filled winner card a medal-coloured disc would
                  // vanish into the background, so it flips to translucent
                  // white with a ring instead.
                  gradient: emphasize
                      ? null
                      : LinearGradient(colors: [medal.withOpacity(0.85), medal]),
                  color: emphasize ? Colors.white.withOpacity(0.25) : null,
                  shape: BoxShape.circle,
                  border: emphasize
                      ? Border.all(color: Colors.white.withOpacity(0.7), width: 2)
                      : null,
                ),
                child: Text(
                  _initials(entry.firstName, entry.lastName),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: emphasize ? 19 : 15,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.fullName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: emphasize ? 13 : 12,
                  color: emphasize ? Colors.white : context.colors.textPrimary,
                ),
              ),
              if (entry.className != null) ...[
                const SizedBox(height: 2),
                Text(
                  entry.className!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: emphasize ? Colors.white70 : context.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: emphasize
                      ? Colors.white.withOpacity(0.24)
                      : medal.withOpacity(0.12),
                  borderRadius: AppRadius.smRadius,
                ),
                child: Text(
                  entry.overallAverage == null
                      ? '—'
                      : entry.overallAverage!.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: emphasize ? 16 : 14,
                    color: emphasize ? Colors.white : medal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.entry, required this.onTap});

  final LeaderboardEntry entry;
  final VoidCallback onTap;

  /// Same bands as the summary card and the pupil's subject bars.
  Color _scoreColor(BuildContext context, double? value) {
    if (value == null) return context.colors.textMuted;
    if (value >= 8) return context.colors.success;
    if (value >= 6) return context.colors.warning;
    return context.colors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor(context, entry.overallAverage);

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
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${entry.position}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.fullName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.className != null)
                      Text(
                        entry.className!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Colour carries the same meaning here as everywhere else the
              // app shows an average, so a director scanning the list sees
              // who is struggling without reading a single number.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.12),
                  borderRadius: AppRadius.smRadius,
                ),
                child: Text(
                  entry.overallAverage == null
                      ? '—'
                      : entry.overallAverage!.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: scoreColor,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.colors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
