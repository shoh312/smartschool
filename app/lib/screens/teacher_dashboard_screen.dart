import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../providers/teacher_provider.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/dashboard_action_tile.dart';
import '../widgets/empty_state.dart';
import 'announcements_screen.dart';
import 'class_roster_screen.dart';
import 'school_calendar_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherProvider>().loadMyClasses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TeacherProvider>();
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.teacherMyClasses,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DashboardSectionHeader(title: l10n.quickActions),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DashboardActionGrid(
              // Materials and the diary aren't here any more: both are
              // permanent tabs in the bottom bar, and a tile that just
              // repeats a tab is a second door to the same room.
              actions: [
                DashboardActionTile(
                  icon: Icons.event_note_rounded,
                  label: l10n.schoolCalendar,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SchoolCalendarScreen()),
                  ),
                ),
                DashboardActionTile(
                  icon: Icons.campaign_rounded,
                  label: l10n.announcements,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AnnouncementsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DashboardSectionHeader(title: l10n.teacherMyClasses),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<TeacherProvider>().loadMyClasses(),
              child: provider.isLoading && provider.myClasses.isEmpty
                  ? const AppLoadingIndicator()
                  : provider.myClasses.isEmpty
                      ? EmptyState(
                          icon: Icons.school_outlined,
                          title: l10n.teacherNoClassesTitle,
                          message: l10n.teacherNoClassesMessage,
                        )
                      : ListView.separated(
                          padding: (const EdgeInsets.fromLTRB(16, 0, 16, 16)).add(bottomNavPadding(context)),
                          itemCount: provider.myClasses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final assignment = provider.myClasses[index];
                            final className = assignment.className ??
                                l10n.classFallbackLabel(assignment.classId.toString());
                            return FadeSlideIn(
                              delay: index < 12
                                  ? Duration(milliseconds: 40 * index)
                                  : Duration.zero,
                              child: AppListCard(
                                leading: AppListBadge(icon: Icons.class_outlined),
                                title: className,
                                subtitle: assignment.subject,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ClassRosterScreen(
                                      classId: assignment.classId,
                                      className: className,
                                      subject: assignment.subject ?? '',
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
