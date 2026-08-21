import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/app_role.dart';
import '../models/material.dart';
import '../providers/auth_provider.dart';
import '../services/material_service.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/empty_state.dart';
import 'assignment_player_screen.dart';

/// What a pupil has been given -- and, with the same screen, what their
/// parent can watch.
///
/// A parent sees identical cards but no way in: only the pupil signed in as
/// themself gets the Start button, otherwise a parent could sit their
/// child's control test for them.
class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key, required this.studentId, this.studentName});

  final int studentId;
  final String? studentName;

  @override
  State<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> {
  List<StudentAssignment> _items = [];
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
      final items =
          await context.read<MaterialService>().fetchStudentAssignments(widget.studentId);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Opening a task means one of two quite different things.
  ///
  /// Only work the pupil may actually still do goes into the player. A
  /// finished control test, or one whose deadline has passed, used to be
  /// opened the same way and blew up with the server's 409 -- the tap was
  /// always "start a new attempt", even when the server had already said
  /// `can_start: false`. Those now open a summary instead, which is what
  /// the pupil was looking for anyway: did it arrive, and what did I get.
  Future<void> _open(StudentAssignment assignment, {required bool isPupil}) async {
    if (!isPupil || !assignment.canStart) {
      await _showSummary(assignment);
      return;
    }
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AssignmentPlayerScreen(
          assignmentId: assignment.id,
          studentId: widget.studentId,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _showSummary(StudentAssignment assignment) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    String status;
    if (assignment.isDone && !assignment.scoreVisible) {
      status = l10n.assignmentWaitingMark;
    } else if (assignment.isOverdue) {
      status = l10n.assignmentOverdue;
    } else if (assignment.attemptsLeft == 0) {
      status = l10n.assignmentNoAttemptsLeft;
    } else {
      status = l10n.assignmentDone;
    }

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assignment.title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  assignment.subject,
                  assignment.isControl
                      ? l10n.materialModeControl
                      : l10n.materialModePractice,
                  if (assignment.teacherName != null) assignment.teacherName!,
                ].join(' · '),
                style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              if (assignment.scoreVisible && assignment.percent != null) ...[
                Text(
                  l10n.assignmentYourScore,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${assignment.score}/${assignment.maxScore}',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${assignment.percent}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.info.withValues(alpha: 0.10),
                  borderRadius: AppRadius.mdRadius,
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 13, height: 1.4, color: colors.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(l10n.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPupil = context.watch<AuthProvider>().role == AppRole.student;

    // Still to do first: an overdue or unfinished task is what a pupil
    // opens this screen to find, and finished work only clutters the top.
    final pending = _items.where((a) => !a.isDone).toList();
    final done = _items.where((a) => a.isDone).toList();

    return AppShell(
      title: widget.studentName == null || widget.studentName!.isEmpty
          ? l10n.assignmentsTitle
          : '${l10n.assignmentsTitle} · ${widget.studentName}',
      child: _loading
          ? const AppLoadingIndicator()
          : _error != null
              ? Center(child: Text(l10n.errorPrefix(_error!)))
              : _items.isEmpty
                  ? EmptyState(
                      icon: Icons.assignment_outlined,
                      title: l10n.assignmentsNoneTitle,
                      message: l10n.assignmentsNoneMessage,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: (const EdgeInsets.fromLTRB(16, 12, 16, 32)).add(bottomNavPadding(context)),
                        children: [
                          for (final assignment in [...pending, ...done])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _AssignmentCard(
                                assignment: assignment,
                                // Tappable for a parent too -- it opens the
                                // read-only summary, never the player.
                                onTap: () => _open(assignment, isPupil: isPupil),
                                canStart: isPupil && assignment.canStart,
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    this.onTap,
    this.canStart = false,
  });

  final StudentAssignment assignment;
  final VoidCallback? onTap;

  /// Whether tapping opens the player. False for a parent, and for work
  /// this pupil can no longer do -- those get the summary sheet instead,
  /// so the chevron shouldn't promise a way in.
  final bool canStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    final (statusText, statusColor) = _status(context, l10n, colors);

    return AppListCard(
      title: assignment.title,
      subtitle: [
        assignment.subject,
        assignment.isControl ? l10n.materialModeControl : l10n.materialModePractice,
        if (assignment.dueAt != null) l10n.assignmentDueLabel(_formatDue(assignment.dueAt!.toLocal())),
      ].where((part) => part.isNotEmpty).join(' · '),
      subtitleMaxLines: 2,
      showChevron: canStart,
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: AppRadius.smRadius,
        ),
        child: Icon(
          assignment.isDone
              ? Icons.check_rounded
              : assignment.isOverdue
                  ? Icons.schedule_rounded
                  : assignment.isControl
                      ? Icons.fact_check_rounded
                      : Icons.fitness_center_rounded,
          size: 19,
          color: statusColor,
        ),
      ),
      trailing: assignment.isDone && assignment.scoreVisible && assignment.percent != null
          ? AppListBadge(text: '${assignment.percent}%', color: statusColor)
          : AppListBadge(text: statusText, color: statusColor),
      onTap: onTap,
    );
  }

  (String, Color) _status(BuildContext context, AppLocalizations l10n, AppColorScheme colors) {
    if (assignment.isDone) {
      // A submitted control test still says nothing about the mark until
      // the deadline -- same rule the server enforces.
      if (!assignment.scoreVisible) return (l10n.assignmentDone, colors.info);
      // Practice can be run again, and saying so is the whole point of
      // practice -- "Done" alone reads as a closed door.
      if (canStart) return (l10n.assignmentRetry, colors.primary);
      return (l10n.assignmentDone, colors.success);
    }
    if (assignment.isOverdue) return (l10n.assignmentOverdue, colors.danger);
    if (assignment.attemptsLeft == 0) return (l10n.assignmentNoAttemptsLeft, colors.textMuted);
    return (l10n.assignmentStart, colors.primary);
  }

  String _formatDue(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)} ${two(value.hour)}:${two(value.minute)}';
  }
}
