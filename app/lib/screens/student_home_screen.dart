import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/student.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../services/student_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/dashboard_action_tile.dart';
import 'achievements_screen.dart';
import 'announcements_screen.dart';
import 'homework_list_screen.dart';
import 'school_calendar_screen.dart';
import 'student_attendance_journal_screen.dart';
import 'student_diary_screen.dart';

/// The student's own home hub -- reached only from their own login (see
/// AuthProvider.loginStudent), never through a parent's session. Every tile
/// reuses an existing screen, driven by the student's own token instead of
/// a parentId (see each screen's `viaPublicServer` flag).
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  Student? _student;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      // So assignment reminders land on the pupil's own phone rather than
      // their parent's -- the parent's device is registered separately, on
      // the parent dashboard.
      context.read<NotificationProvider>().registerStudentDevice();
    });
  }

  Future<void> _load() async {
    try {
      final students = await context.read<StudentService>().fetchStudents(viaPublicServer: true);
      if (mounted && students.isNotEmpty) setState(() => _student = students.first);
    } catch (_) {
      // Header falls back to a generic label; the tiles below still work
      // off the studentId already held by AuthProvider.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final studentId = context.watch<AuthProvider>().studentId;
    final student = _student;

    return AppShell(
      title: l10n.studentHomeTitle,
      // Language and sign-out both live in the Settings tab now, so the
      // app bar stays empty rather than carrying a second copy of them.
      child: studentId == null
          ? const SizedBox.shrink()
          : ListView(
              padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: AppRadius.lgRadius,
                    boxShadow: AppShadows.colored(context.colors.primary),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(
                          (student?.firstName.isNotEmpty ?? false) ? student!.firstName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student?.fullName ?? l10n.studentHomeTitle,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                            if (student?.className != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                student!.className!,
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                DashboardSectionHeader(title: l10n.sectionLearning),
                // Assignments, grades and the rating aren't here any more: all
                // three are permanent tabs in the bottom bar, and a tile
                // repeating a tab is a second door to the same room.
                DashboardActionGrid(
                  actions: [
                    DashboardActionTile(
                      icon: Icons.menu_book_rounded,
                      label: l10n.ruznoma,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentDiaryScreen(studentId: studentId, studentName: student?.fullName ?? ''),
                        ),
                      ),
                    ),
                    DashboardActionTile(
                      icon: Icons.assignment_outlined,
                      label: l10n.homeworkListTitle,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomeworkListScreen(studentId: studentId, studentName: student?.fullName ?? ''),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                DashboardSectionHeader(title: l10n.sectionSchool),
                DashboardActionGrid(
                  actions: [
                    DashboardActionTile(
                      icon: Icons.event_available_rounded,
                      label: l10n.attendanceHistory,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentAttendanceJournalScreen(
                            studentId: studentId,
                            studentName: student?.fullName ?? '',
                            viaPublicServer: true,
                          ),
                        ),
                      ),
                    ),
                    DashboardActionTile(
                      icon: Icons.emoji_events_rounded,
                      label: l10n.achievementsTitle,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AchievementsScreen(studentId: studentId)),
                      ),
                    ),
                    DashboardActionTile(
                      icon: Icons.calendar_month_rounded,
                      label: l10n.schoolCalendar,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SchoolCalendarScreen(studentId: studentId)),
                      ),
                    ),
                    DashboardActionTile(
                      icon: Icons.campaign_rounded,
                      label: l10n.announcements,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AnnouncementsScreen(studentId: studentId)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
