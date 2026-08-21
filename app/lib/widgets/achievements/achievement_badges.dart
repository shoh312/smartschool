import 'package:flutter/material.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../../core/design_tokens.dart';
import '../../models/analytics.dart';
import '../analytics/analytics_widgets.dart';

class Achievement {
  const Achievement({required this.icon, required this.title, required this.color});

  final IconData icon;
  final String title;
  final Color color;
}

/// Derives a badge set purely from data the student's analytics overview
/// already carries -- no stored/triggered gamification table, no new
/// backend endpoint. Recomputed fresh every time the overview is fetched,
/// same "compute, don't store" choice already made for quarterly trend.
List<Achievement> computeAchievements(AppLocalizations l10n, StudentAnalyticsOverview overview) {
  final achievements = <Achievement>[];

  if (overview.schoolRank.position == 1) {
    achievements.add(Achievement(icon: Icons.emoji_events_rounded, title: l10n.achievementSchoolFirst, color: RankColors.gold));
  } else if (RankColors.isTopThree(overview.schoolRank.position) ||
      RankColors.isTopThree(overview.classRank.position) ||
      RankColors.isTopThree(overview.parallelRank.position)) {
    achievements.add(Achievement(icon: Icons.military_tech_rounded, title: l10n.achievementTopThreeBadge, color: RankColors.bronze));
  }

  if (overview.overallAverage != null && overview.overallAverage! >= 9) {
    achievements.add(Achievement(icon: Icons.star_rounded, title: l10n.achievementExcellent, color: Colors.amber.shade700));
  }

  if (overview.lessonAttendanceRate != null && overview.lessonAttendanceRate! >= 95) {
    achievements.add(Achievement(icon: Icons.event_available_rounded, title: l10n.achievementPerfectAttendance, color: Colors.green.shade600));
  }

  final trendPoints = overview.trend.where((p) => p.overallAverage != null).toList();
  if (trendPoints.length >= 2) {
    final delta = trendPoints.last.overallAverage! - trendPoints[trendPoints.length - 2].overallAverage!;
    if (delta >= 1.0) {
      achievements.add(Achievement(icon: Icons.trending_up_rounded, title: l10n.achievementBigImprovement, color: Colors.blue.shade600));
    }
  }

  if (overview.subjectBreakdown.isNotEmpty && overview.subjectBreakdown.first.average >= 9) {
    achievements.add(Achievement(
      icon: Icons.workspace_premium_rounded,
      title: l10n.achievementSubjectMaster(overview.subjectBreakdown.first.subject),
      color: Colors.deepPurple.shade400,
    ));
  }

  return achievements;
}

/// A responsive grid of gold-gradient badge chips, matching the rating
/// screens' visual language ([RankColors], [AppGradients]).
class AchievementGrid extends StatelessWidget {
  const AchievementGrid({super.key, required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth > 700 ? 3 : 2;
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final achievement in achievements)
              SizedBox(width: tileWidth, child: _AchievementTile(achievement: achievement)),
          ],
        );
      },
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final color = achievement.color;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: AppShadows.colored(color),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.85), color]),
              shape: BoxShape.circle,
            ),
            child: Icon(achievement.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
