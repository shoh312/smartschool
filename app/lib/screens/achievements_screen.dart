import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../models/analytics.dart';
import '../services/analytics_service.dart';
import '../widgets/achievements/achievement_badges.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/empty_state.dart';

/// "Yutuqlar" -- achievement badges derived from the student's current
/// analytics overview (rank, average, attendance, trend, strongest subject).
/// See computeAchievements in achievement_badges.dart for the rules.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key, required this.studentId, this.parentId});

  final int studentId;
  final int? parentId;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  StudentAnalyticsOverview? _overview;
  bool _loading = true;
  String? _error;

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
      final overview = await context.read<AnalyticsService>().studentOverview(
            studentId: widget.studentId,
            parentId: widget.parentId,
            viaPublicServer: true,
          );
      if (mounted) setState(() => _overview = overview);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final overview = _overview;

    return AppShell(
      title: l10n.achievementsTitle,
      child: _loading
          ? const AppLoadingIndicator()
          : _error != null
              ? Center(child: Text(l10n.errorPrefix(_error!)))
              : overview == null
                  ? EmptyState(icon: Icons.emoji_events_outlined, title: l10n.noDataTitle, message: l10n.noGradesYetMessage)
                  : Builder(builder: (context) {
                      final achievements = computeAchievements(l10n, overview);
                      return RefreshIndicator(
                        onRefresh: _load,
                        child: achievements.isEmpty
                            ? ListView(
                                children: [
                                  EmptyState(
                                    icon: Icons.emoji_events_outlined,
                                    title: l10n.noAchievementsTitle,
                                    message: l10n.noAchievementsMessage,
                                  ),
                                ],
                              )
                            : ListView(
                                padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
                                children: [AchievementGrid(achievements: achievements)],
                              ),
                      );
                    }),
    );
  }
}
