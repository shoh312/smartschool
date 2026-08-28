import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/student.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/student_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/dashboard_action_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/student_tile.dart';
import 'student_assignments_screen.dart';
import 'student_attendance_journal_screen.dart';
import 'student_diary_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final parentId = context.read<AuthProvider>().parentId;
      if (parentId != null) {
        context.read<StudentProvider>().loadStudents(parentId: parentId);
        context.read<NotificationProvider>().initialize(parentId);
      }
    });
  }

  Future<void> _openGrades() async {
    final target = await _selectChild();
    if (target == null || !mounted) return;
    Navigator.pushNamed(context, AppRoutes.studentDetails, arguments: target);
  }

  Future<Student?> _selectChild() async {
    final children = context.read<StudentProvider>().students;
    if (children.isEmpty) return null;
    if (children.length == 1) return children.first;

    final l10n = AppLocalizations.of(context)!;
    return showModalBottomSheet<Student>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.colors.borderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              DashboardSectionHeader(title: l10n.children),
              for (final child in children) ...[
                Material(
                  color: context.colors.surfaceAlt,
                  borderRadius: AppRadius.mdRadius,
                  child: InkWell(
                    borderRadius: AppRadius.mdRadius,
                    onTap: () => Navigator.pop(context, child),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text(
                              child.firstName.isEmpty ? '?' : child.firstName[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(child.fullName, style: Theme.of(context).textTheme.titleSmall),
                          ),
                          Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
                if (child != children.last) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// A parent asks "was my child at school", which is a question about one
  /// child and one month -- so this opens the pupil's own month calendar,
  /// not the flat school-wide list the director reads.
  Future<void> _openAttendance() async {
    final target = await _selectChild();
    if (target == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentAttendanceJournalScreen(
          studentId: target.id,
          studentName: target.fullName,
          parentId: context.read<AuthProvider>().parentId,
        ),
      ),
    );
  }

  Future<void> _openDiary() async {
    final target = await _selectChild();
    if (target == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDiaryScreen(studentId: target.id, studentName: target.fullName),
      ),
    );
  }

  /// Read-only for a parent: the same screen the pupil uses, but with no
  /// way in -- StudentAssignmentsScreen only offers Start to a session
  /// signed in as the pupil themself.
  Future<void> _openAssignments() async {
    final target = await _selectChild();
    if (target == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentAssignmentsScreen(
          studentId: target.id,
          studentName: target.fullName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentProvider>();
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.parentDashboard,
      actions: [
        // Language moved to the Settings tab; notifications stay here
        // because a parent has no tab for them.
        IconButton(
          tooltip: l10n.notifications,
          icon: Icon(Icons.notifications_none_rounded, size: 24),
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.notifications),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          final parentId = context.read<AuthProvider>().parentId;
          await students.loadStudents(parentId: parentId);
        },
        child: students.isLoading
            ? const AppLoadingIndicator()
            : students.students.isEmpty
            ? EmptyState(
                icon: Icons.groups_2_outlined,
                title: l10n.noChildrenLinked,
                message: l10n.assignedStudentsWillAppear,
              )
            : ListView.separated(
                padding: (const EdgeInsets.all(16)).add(bottomNavPadding(context)),
                itemCount: students.students.length + 2,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final tiles = [
                      DashboardActionTile(
                        icon: Icons.event_available_rounded,
                        label: l10n.attendanceHistory,
                        onTap: _openAttendance,
                      ),
                      DashboardActionTile(
                        icon: Icons.grading_rounded,
                        label: l10n.grades,
                        onTap: _openGrades,
                      ),
                      DashboardActionTile(
                        icon: Icons.menu_book_rounded,
                        label: l10n.ruznoma,
                        onTap: _openDiary,
                      ),
                      DashboardActionTile(
                        icon: Icons.auto_stories_rounded,
                        label: l10n.assignmentsTitle,
                        onTap: _openAssignments,
                      ),
                      // The calendar, announcements and rating are
                      // permanent tabs in the bottom bar now, so they're
                      // gone from here -- a tile repeating a tab is a
                      // second door to the same room.
                    ];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DashboardSectionHeader(title: l10n.quickActions),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const spacing = 12.0;
                            final columns = constraints.maxWidth > 700 ? 3 : 2;
                            final tileWidth =
                                (constraints.maxWidth - spacing * (columns - 1)) / columns;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: [
                                for (var i = 0; i < tiles.length; i++)
                                  SizedBox(
                                    width: tileWidth,
                                    child: FadeSlideIn(
                                      delay: Duration(milliseconds: 40 * i),
                                      child: tiles[i],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  }
                  if (index == 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: DashboardSectionHeader(title: l10n.children),
                    );
                  }
                  final studentIndex = index - 2;
                  return FadeSlideIn(
                    delay: studentIndex < 12 ? Duration(milliseconds: 40 * studentIndex) : Duration.zero,
                    child: StudentTile(student: students.students[studentIndex]),
                  );
                },
              ),
      ),
    );
  }
}

