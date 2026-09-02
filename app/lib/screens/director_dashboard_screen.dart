import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/school_provider.dart';
import '../providers/student_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/dashboard_action_tile.dart';
import '../widgets/empty_state.dart';
import 'package:smartschool_app/generated/app_localizations.dart';
import '../services/analytics_service.dart';
import 'announcements_screen.dart';
import 'class_attendance_analytics_screen.dart';
import 'class_diary_screen.dart';
import 'needs_attention_screen.dart';
import 'school_calendar_screen.dart';
import 'windows_dashboard_screen.dart';

class DirectorDashboardScreen extends StatefulWidget {
  const DirectorDashboardScreen({super.key, this.isIntegrated = false});

  final bool isIntegrated;

  @override
  State<DirectorDashboardScreen> createState() =>
      _DirectorDashboardScreenState();
}

class _DirectorDashboardScreenState extends State<DirectorDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents();
      context.read<SchoolProvider>().loadSchoolData();
      final attendance = context.read<AttendanceProvider>();
      attendance.loadLive();
      attendance.startRealtime();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Desktop gets its own dashboard entirely.
    //
    // Not a wider version of this one: the two are opened for different
    // reasons. A phone is picked up for a minute to answer one question, so
    // it shows shortcuts. A desktop in the office stays open all morning,
    // where a live picture of who has arrived is worth more than a grid of
    // buttons the director has already learned by heart.
    //
    // Windows only, deliberately -- this is the machine the school actually
    // has on a desk.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return WindowsDashboardScreen(isIntegrated: widget.isIntegrated);
    }

    final students = context.watch<StudentProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final school = context.watch<SchoolProvider>();
    final l10n = AppLocalizations.of(context)!;

    final live = attendance.live;
    int count(AttendanceStatus status) =>
        live.where((item) => item.status == status).length;

    final studentsById = {
      for (final student in students.students) student.id: student,
    };
    final totalByClass = <int, int>{};
    for (final student in students.students) {
      final classId = student.classId;
      if (classId == null) continue;
      totalByClass[classId] = (totalByClass[classId] ?? 0) + 1;
    }
    const arrivedStatuses = {
      AttendanceStatus.present,
      AttendanceStatus.late,
      AttendanceStatus.leftSchool,
    };
    final arrivedByClass = <int, int>{};
    final presentByClass = <int, int>{};
    final lateByClass = <int, int>{};
    final absentByClass = <int, int>{};
    for (final item in live) {
      final classId = studentsById[item.studentId]?.classId;
      if (classId == null) continue;
      if (arrivedStatuses.contains(item.status)) {
        arrivedByClass[classId] = (arrivedByClass[classId] ?? 0) + 1;
      }
      switch (item.status) {
        case AttendanceStatus.present:
          presentByClass[classId] = (presentByClass[classId] ?? 0) + 1;
        case AttendanceStatus.late:
          lateByClass[classId] = (lateByClass[classId] ?? 0) + 1;
        case AttendanceStatus.absent:
          absentByClass[classId] = (absentByClass[classId] ?? 0) + 1;
        default:
          break;
      }
    }

    Widget body = RefreshIndicator(
      onRefresh: () async {
        await students.loadStudents();
        await attendance.loadLive();
      },
      child: ListView(
        // Extra bottom clearance so the last row can scroll fully clear of
        // the floating bottom nav bar instead of ending under it.
        padding: (const EdgeInsets.fromLTRB(16, 8, 16, 24)).add(bottomNavPadding(context)),
        children: [
          FadeSlideIn(
            child: AttendanceHeroCard(
              total: students.students.length,
              present: count(AttendanceStatus.present),
              late: count(AttendanceStatus.late),
              absent: count(AttendanceStatus.absent),
            ),
          ),
          const SizedBox(height: 26),

          // Quick actions are split into two named groups instead of one
          // eight-tile grid, and "Live stream" is gone from here entirely --
          // it already has its own bottom-nav tab, so listing it twice made
          // the tab bar stop meaning "where am I".
          DashboardSectionHeader(title: l10n.sectionLearning),
          FadeSlideIn(
            delay: const Duration(milliseconds: 40),
            child: DashboardActionGrid(
              actions: [
                DashboardActionTile(
                  icon: Icons.menu_book_rounded,
                  label: l10n.ruznoma,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ClassDiaryScreen()),
                  ),
                ),
                // No "Grades" tile here: the journal already lives one tap
                // inside Management > Classes, and a second door to it made
                // the same destination appear in two unrelated places.
                DashboardActionTile(
                  icon: Icons.warning_amber_rounded,
                  label: l10n.needsAttention,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NeedsAttentionScreen(
                        scope: RankingScope.school,
                        title: l10n.needsAttention,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          DashboardSectionHeader(title: l10n.sectionSchool),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: DashboardActionGrid(
              actions: [
                DashboardActionTile(
                  icon: Icons.calendar_month_rounded,
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
                DashboardActionTile(
                  icon: Icons.history_rounded,
                  label: l10n.history,
                  route: AppRoutes.attendanceHistory,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          DashboardSectionHeader(title: l10n.attendanceByClass),
          if (school.classes.isEmpty)
            SizedBox(
              height: 200,
              child: EmptyState(
                icon: Icons.class_outlined,
                title: l10n.noDataTitle,
                message: l10n.noClasses,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                // One column at phone widths (cards read as a normal list),
                // 2-3 on wide windows instead of a single full-bleed column
                // stretched edge to edge.
                final columns = constraints.maxWidth > 900
                    ? 3
                    : constraints.maxWidth > 600
                        ? 2
                        : 1;
                final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                final cards = (List.of(school.classes)
                      ..sort((a, b) {
                        final byGrade = a.grade.compareTo(b.grade);
                        return byGrade != 0 ? byGrade : a.name.compareTo(b.name);
                      }))
                    .asMap()
                    .entries
                    .map((mapEntry) {
                  final cardIndex = mapEntry.key;
                  final schoolClass = mapEntry.value;
                  return FadeSlideIn(
                    delay: cardIndex < 12
                        ? Duration(milliseconds: 40 * cardIndex)
                        : Duration.zero,
                    child: ClassAttendanceCard(
                      grade: schoolClass.grade,
                      name: schoolClass.name,
                      total: totalByClass[schoolClass.id] ?? 0,
                      arrived: arrivedByClass[schoolClass.id] ?? 0,
                      present: presentByClass[schoolClass.id] ?? 0,
                      late: lateByClass[schoolClass.id] ?? 0,
                      absent: absentByClass[schoolClass.id] ?? 0,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClassAttendanceAnalyticsScreen(
                            schoolClass: schoolClass,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList();

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final card in cards) SizedBox(width: tileWidth, child: card),
                  ],
                );
              },
            ),
        ],
      ),
    );

    if (widget.isIntegrated) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.dashboard),
          actions: [
            IconButton(
              tooltip: l10n.history,
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.attendanceHistory),
            ),
          ],
        ),
        body: body,
      );
    }

    return AppShell(
      title: l10n.directorDashboard,
      actions: [
        IconButton(
          tooltip: l10n.notifications,
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.notifications),
        ),
      ],
      child: body,
    );
  }
}
