import 'package:flutter/material.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../models/app_role.dart';

/// One bottom-nav destination, consumed by [AppBottomNav].
///
/// Carries both an outline and a filled icon: the bar marks the current tab
/// by filling its icon in, which reads at a glance even before the label
/// underneath it animates in.
class NavDestinationData {
  const NavDestinationData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// The bar each role sees.
///
/// Deliberately not the same five tabs for everybody. A bottom bar only
/// earns its space when the destinations are things you move *between* --
/// otherwise it's a permanent strip repeating the home screen's tiles. So
/// each role gets the handful it actually alternates between during a day,
/// and everything else stays a drill-down from home.
///
/// Profile is last for every role, and is the only place to sign out.
/// Settings sits one tap inside it: nobody looks for "settings" to
/// answer "whose session is this" or "how do I sign out".
List<NavDestinationData> navDestinationsFor(AppRole? role, AppLocalizations l10n) {
  switch (role) {
    case AppRole.director:
      return [
        NavDestinationData(
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard_rounded,
          label: l10n.dashboard,
        ),
        NavDestinationData(
          icon: Icons.videocam_outlined,
          activeIcon: Icons.videocam_rounded,
          label: l10n.live,
        ),
        NavDestinationData(
          icon: Icons.tune_outlined,
          activeIcon: Icons.tune_rounded,
          label: l10n.manage,
        ),
        // Where the school stands, not what just happened in it. Alerts
        // used to sit here, but a bell is something you answer once and
        // leave -- the dashboard's own bell is the right size for that,
        // while the ranking is a page a director comes back to.
        NavDestinationData(
          icon: Icons.leaderboard_outlined,
          activeIcon: Icons.leaderboard_rounded,
          label: l10n.ratingAnalytics,
        ),
        NavDestinationData(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: l10n.profileTitle,
        ),
      ];

    case AppRole.teacher:
      // A teacher's day is spent going between writing material, filling in
      // the diary, and their class list -- not drilling into one thing.
      return [
        NavDestinationData(
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard_rounded,
          label: l10n.dashboard,
        ),
        NavDestinationData(
          icon: Icons.auto_stories_outlined,
          activeIcon: Icons.auto_stories_rounded,
          label: l10n.materialsTitle,
        ),
        NavDestinationData(
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book_rounded,
          label: l10n.ruznoma,
        ),
        NavDestinationData(
          icon: Icons.auto_awesome_outlined,
          activeIcon: Icons.auto_awesome_rounded,
          label: l10n.aiTitle,
        ),
        NavDestinationData(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: l10n.profileTitle,
        ),
      ];

    case AppRole.parent:
      // Everything a parent reads about their own child needs a child
      // chosen first, so those stay on the home hub where the picker is.
      // The tabs are the school-wide pages, which need no such choice.
      return [
        NavDestinationData(
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard_rounded,
          label: l10n.dashboard,
        ),
        NavDestinationData(
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign_rounded,
          label: l10n.announcements,
        ),
        NavDestinationData(
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month_rounded,
          label: l10n.schoolCalendar,
        ),
        NavDestinationData(
          icon: Icons.leaderboard_outlined,
          activeIcon: Icons.leaderboard_rounded,
          label: l10n.ratingAnalytics,
        ),
        NavDestinationData(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: l10n.profileTitle,
        ),
      ];

    case AppRole.student:
      // Nine tiles on one page is a lot; a pupil opens the same few every
      // day -- their work, their marks, where they stand -- so those get a
      // permanent seat.
      return [
        NavDestinationData(
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard_rounded,
          label: l10n.dashboard,
        ),
        NavDestinationData(
          icon: Icons.auto_stories_outlined,
          activeIcon: Icons.auto_stories_rounded,
          label: l10n.assignmentsTitle,
        ),
        NavDestinationData(
          icon: Icons.grading_outlined,
          activeIcon: Icons.grading_rounded,
          label: l10n.grades,
        ),
        NavDestinationData(
          icon: Icons.leaderboard_outlined,
          activeIcon: Icons.leaderboard_rounded,
          label: l10n.ratingAnalytics,
        ),
        NavDestinationData(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: l10n.profileTitle,
        ),
      ];

    case null:
      return const [];
  }
}
