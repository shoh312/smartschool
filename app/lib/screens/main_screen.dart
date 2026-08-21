import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/app_role.dart';
import '../providers/auth_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/school_provider.dart';
import '../providers/student_provider.dart';
import '../providers/teacher_admin_provider.dart';
import '../screens/director_dashboard_screen.dart';
import '../screens/live_attendance_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/student_management_screen.dart';
import '../screens/class_management_screen.dart';
import '../screens/ai_material_screen.dart';
import '../screens/announcements_screen.dart';
import '../screens/camera_management_screen.dart';
import '../screens/class_diary_screen.dart';
import '../screens/parent_dashboard_screen.dart';
import '../screens/school_calendar_screen.dart';
import '../screens/student_analytics_screen.dart';
import '../screens/student_assignments_screen.dart';
import '../screens/student_home_screen.dart';
import '../screens/student_journal_screen.dart';
import '../screens/teacher_dashboard_screen.dart';
import '../screens/material_library_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/teacher_management_screen.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/app_bottom_nav.dart';

/// The tabbed shell every signed-in role lands on.
///
/// The tabs themselves differ per role (see navDestinationsFor) -- a
/// teacher's three working areas are not a director's five -- but the shell
/// around them is shared, so the bar behaves identically everywhere and
/// screens pushed on top keep it via AppShell.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  /// Must line up one-to-one with navDestinationsFor(role).
  static List<Widget> _pagesFor(AppRole? role) {
    switch (role) {
      case AppRole.director:
        return const [
          DirectorDashboardScreen(isIntegrated: true),
          LiveAttendanceScreen(isIntegrated: true),
          _ManagementTab(),
          SettingsScreen(),
          NotificationScreen(isIntegrated: true),
        ];
      case AppRole.teacher:
        return const [
          TeacherDashboardScreen(),
          MaterialLibraryScreen(),
          ClassDiaryScreen(),
          AiMaterialScreen(),
          SettingsScreen(),
        ];
      case AppRole.parent:
        return const [
          ParentDashboardScreen(),
          _ParentTab(_ParentSection.announcements),
          _ParentTab(_ParentSection.calendar),
          _ParentTab(_ParentSection.rating),
          SettingsScreen(),
        ];
      case AppRole.student:
        return const [
          StudentHomeScreen(),
          _StudentTab(_StudentSection.assignments),
          _StudentTab(_StudentSection.grades),
          _StudentTab(_StudentSection.rating),
          SettingsScreen(),
        ];
      case null:
        return const [SizedBox.shrink()];
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role;
    final pages = _pagesFor(role);
    // Clamped because the tab count changes with the role: a director on
    // tab 4 who signs out and back in as a teacher would otherwise index
    // past the end of a four-page list.
    final currentIndex =
        context.watch<NavProvider>().currentIndex.clamp(0, pages.length - 1);
    void onSelect(int index) => context.read<NavProvider>().setIndex(index);

    final content = IndexedStack(index: currentIndex, children: pages);

    return Scaffold(
      // The nav bar is a detached floating pill, so the body has to run all
      // the way to the bottom edge behind it -- otherwise Scaffold reserves
      // an opaque strip the pill's height and content visibly stops dead at
      // its top edge instead of scrolling under the pill.
      extendBody: true,
      body: content,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: currentIndex,
        onDestinationSelected: onSelect,
      ),
    );
  }
}

/// The Management tab: a hub of four destinations, each opening as its own
/// full screen.
///
/// Was a `TabBar` of four embedded screens -- a second row of tabs sitting
/// under the bottom nav's own tabs, which left no clear answer to "where am
/// I" and gave each section no room for a title or actions of its own. A
/// plain list also lets each row carry its live count, which the tab strip
/// could not.
class _ManagementTab extends StatefulWidget {
  const _ManagementTab();

  @override
  State<_ManagementTab> createState() => _ManagementTabState();
}

class _ManagementTabState extends State<_ManagementTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Loaded here rather than inside each destination so the counts below
      // are right before you open anything.
      context.read<SchoolProvider>().loadSchoolData();
      context.read<StudentProvider>().loadStudents();
      context.read<TeacherAdminProvider>().loadTeachers();
    });
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final school = context.watch<SchoolProvider>();
    final students = context.watch<StudentProvider>();
    final teachers = context.watch<TeacherAdminProvider>();

    final destinations = <_ManagementDestination>[
      _ManagementDestination(
        icon: Icons.groups_2_outlined,
        label: l10n.students,
        count: students.students.length,
        onTap: () => _open(const StudentManagementScreen()),
      ),
      _ManagementDestination(
        icon: Icons.class_outlined,
        label: l10n.classes,
        count: school.classes.length,
        onTap: () => _open(const ClassManagementScreen()),
      ),
      _ManagementDestination(
        icon: Icons.videocam_outlined,
        label: l10n.cameras,
        count: school.cameras.length,
        onTap: () => _open(const CameraManagementScreen()),
      ),
      _ManagementDestination(
        icon: Icons.school_outlined,
        label: l10n.teachers,
        count: teachers.teachers.length,
        onTap: () => _open(const TeacherManagementScreen()),
      ),
      // Read-only for a director: what the teachers have written and what
      // their classes are doing with it. No count -- materials aren't a
      // roster the director maintains, so a number here would suggest an
      // ownership they don't have.
      _ManagementDestination(
        icon: Icons.auto_stories_outlined,
        label: l10n.materialsTitle,
        onTap: () => _open(const MaterialLibraryScreen()),
      ),
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: (const EdgeInsets.fromLTRB(16, 8, 16, 24)).add(bottomNavPadding(context)),
        children: [
          DashboardSectionHeader(title: l10n.manage),
          for (var i = 0; i < destinations.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FadeSlideIn(
                delay: Duration(milliseconds: 40 * i),
                child: AppListCard(
                  leading: AppListBadge(icon: destinations[i].icon),
                  title: destinations[i].label,
                  onTap: destinations[i].onTap,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (destinations[i].count != null) ...[
                        Text(
                          '${destinations[i].count}',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: context.colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManagementDestination {
  const _ManagementDestination({
    required this.icon,
    required this.label,
    this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// Null where a number would be misleading rather than useful -- see
  /// the materials destination.
  final int? count;
  final VoidCallback onTap;
}


/// Which of the pupil's own screens a tab shows.
enum _StudentSection { assignments, grades, rating }

/// The pupil's id lives in AuthProvider, not in a const list, so their tabs
/// are resolved here at build time instead.
class _StudentTab extends StatelessWidget {
  const _StudentTab(this.section);

  final _StudentSection section;

  @override
  Widget build(BuildContext context) {
    final studentId = context.watch<AuthProvider>().studentId;
    if (studentId == null) return const SizedBox.shrink();

    return switch (section) {
      _StudentSection.assignments =>
        StudentAssignmentsScreen(studentId: studentId),
      _StudentSection.grades => StudentJournalScreen(
          studentId: studentId,
          studentName: '',
          // A pupil's own session reaches their grades through the Public
          // Server; the school's LAN isn't reachable from home.
          viaPublicServer: true,
        ),
      _StudentSection.rating => StudentAnalyticsScreen(
          studentId: studentId,
          studentName: '',
          viaPublicServer: true,
        ),
    };
  }
}


/// Which school-wide screen a parent's tab shows.
enum _ParentSection { announcements, calendar, rating }

/// Resolves the child these screens need before building them.
///
/// Both take a student id, and without one they fall back to the local
/// server -- the director/teacher path, which a parent sitting at home
/// cannot reach at all. So the tab supplies the child rather than letting
/// the screen guess.
///
/// The first child is used. For the common case (one child) that is simply
/// correct; a parent with several picks the child on the home tab, where
/// everything genuinely child-specific already lives.
class _ParentTab extends StatefulWidget {
  const _ParentTab(this.section);

  final _ParentSection section;

  @override
  State<_ParentTab> createState() => _ParentTabState();
}

class _ParentTabState extends State<_ParentTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // parentId is not decoration: without it StudentService asks the
      // *school* server for the whole roll, which a parent at home cannot
      // reach -- the call fails, the provider blanks its list, and both
      // this tab and the dashboard end up stuck on a spinner.
      final provider = context.read<StudentProvider>();
      final parentId = context.read<AuthProvider>().parentId;
      if (provider.students.isEmpty && parentId != null) {
        provider.loadStudents(parentId: parentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final children = context.watch<StudentProvider>().students;
    if (children.isEmpty) return const AppLoadingIndicator();
    final studentId = children.first.id;

    return switch (widget.section) {
      _ParentSection.announcements => AnnouncementsScreen(studentId: studentId),
      _ParentSection.calendar => SchoolCalendarScreen(studentId: studentId),
      _ParentSection.rating => StudentAnalyticsScreen(
          studentId: studentId,
          studentName: children.first.fullName,
          parentId: context.read<AuthProvider>().parentId,
        ),
    };
  }
}
