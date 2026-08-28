import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/student.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../services/student_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/attendance/attendance_streak.dart';
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
    // The streak under the header comes off the same history the attendance
    // page loads -- one request, and the number a pupil opens the app for is
    // on screen without them having to go looking for it.
    final studentId = context.read<AuthProvider>().studentId;
    if (studentId != null) {
      context.read<AttendanceProvider>().loadHistory(
            studentId: studentId,
            viaPublicServer: true,
          );
    }
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
    final streak = computeAttendanceStreak(context.watch<AttendanceProvider>().history);

    return AppShell(
      title: l10n.studentHomeTitle,
      // The app bar is off here: its only job on this screen was to repeat
      // a generic title above a card repeating the pupil's own name. The
      // header below says who you are in one line and gives the space back
      // to the things you came for.
      showAppBar: false,
      child: studentId == null
          ? const SizedBox.shrink()
          : ListView(
              padding: (const EdgeInsets.fromLTRB(20, 12, 20, 16))
                  .add(bottomNavPadding(context)),
              children: [
                _IdentityHeader(student: student),
                // Only once there is a history to count: a zero on the
                // first day reads as a scolding for something the pupil has
                // not had a chance to do yet.
                if (!streak.isEmpty) ...[
                  const SizedBox(height: 18),
                  AttendanceStreakCard(streak: streak),
                ],
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

/// Who is signed in, in one line.
///
/// Replaces the gradient card that used to open this screen. That card
/// showed a pupil their own name and class in 120px of colour -- the two
/// facts they are least in need of being told, and both already on the
/// Profile tab. Name on the left, the class beneath it, and the avatar
/// where a thumb can reach it.
class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.student});

  final Student? student;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final initial = (student?.firstName.isNotEmpty ?? false)
        ? student!.firstName[0].toUpperCase()
        : '?';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                student?.fullName ?? l10n.studentHomeTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
              // Nothing rather than a placeholder: a second line repeating
              // the first is worse than one line.
              if (student?.className != null) ...[
                const SizedBox(height: 3),
                Text(
                  student!.className!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 14),
        // The initial rather than the face photo: those images live on the
        // school's own server for recognition, and this screen runs off the
        // Public Server, where they may not be reachable at all.
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            gradient: AppGradients.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }
}
