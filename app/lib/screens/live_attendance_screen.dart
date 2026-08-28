import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../providers/school_provider.dart';
import '../services/school_service.dart';
import '../providers/student_provider.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/app_list_card.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/empty_state.dart';
import 'class_live_attendance_screen.dart';

class LiveAttendanceScreen extends StatefulWidget {
  const LiveAttendanceScreen({super.key, this.isIntegrated = false});

  final bool isIntegrated;

  @override
  State<LiveAttendanceScreen> createState() => _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends State<LiveAttendanceScreen> {
  /// Null until the school's own setting has been read. Nothing is
  /// shown either way in that moment -- flashing the class list and
  /// then replacing it with "turned off" is worse than a blank second.
  bool? _liveEnabled;

  /// Groups a room-mounted camera covers through its timetable. In group mode
  /// a camera carries no class id at all, so without this every group would
  /// wear the "no camera" mark while a camera was pointed straight at it.
  Set<int> _coveredByPosition = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<StudentProvider>().loadStudents();
      _loadLiveSetting();
      // Awaited: the coverage pass reads the camera list this call fills in.
      await context.read<SchoolProvider>().loadSchoolData();
      if (mounted) await _loadPositionCoverage();
    });
  }

  Future<void> _loadPositionCoverage() async {
    final service = context.read<SchoolService>();
    final cameras = context.read<SchoolProvider>().cameras;
    final covered = <int>{};
    for (final camera in cameras.where((c) => c.isActive && c.classId == null)) {
      try {
        for (final position in await service.fetchPositions(camera.id)) {
          covered.add(position.classId);
        }
      } catch (_) {
        // A camera whose slots cannot be read simply contributes nothing;
        // the list is still correct for every other one.
      }
    }
    if (mounted && covered.isNotEmpty) {
      setState(() => _coveredByPosition = covered);
    }
  }

  Future<void> _loadLiveSetting() async {
    try {
      final settings = await context.read<SchoolService>().fetchSettings();
      if (mounted) setState(() => _liveEnabled = settings.liveVideoEnabled);
    } catch (_) {
      // Unreadable setting must not hide a working camera: the server
      // refuses the stream itself when it is off, so the worst case
      // here is the old behaviour rather than a blank screen.
      if (mounted) setState(() => _liveEnabled = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final school = context.watch<SchoolProvider>();
    final students = context.watch<StudentProvider>();
    final l10n = AppLocalizations.of(context)!;

    final countByClass = <int, int>{};
    for (final student in students.students) {
      final classId = student.classId;
      if (classId == null) continue;
      countByClass[classId] = (countByClass[classId] ?? 0) + 1;
    }

    final classIdsWithCamera = school.cameras
        .where((c) => c.isActive && c.classId != null)
        .map((c) => c.classId)
        .toSet()
      ..addAll(_coveredByPosition);

    final classes = List.of(school.classes)
      ..sort((a, b) {
        final byGrade = b.grade.compareTo(a.grade);
        return byGrade != 0 ? byGrade : a.name.compareTo(b.name);
      });

    if (_liveEnabled == false) {
      return AppShell(
        title: l10n.live,
        showAppBar: !widget.isIntegrated,
        child: EmptyState(
          icon: Icons.videocam_off_outlined,
          title: l10n.liveVideoOffByDirector,
          message: l10n.liveVideoSettingHint,
        ),
      );
    }

    final body = RefreshIndicator(
      onRefresh: () async {
        await school.loadSchoolData();
        await students.loadStudents();
      },
      child: classes.isEmpty && !school.isLoading
          ? SizedBox(
              height: 300,
              child: EmptyState(
                icon: Icons.class_outlined,
                title: l10n.noClasses,
                message: l10n.createClassesMessage,
              ),
            )
          : ListView(
              padding: (const EdgeInsets.fromLTRB(16, 8, 16, 24)).add(bottomNavPadding(context)),
              children: [
                // Embedded as a tab this screen has no AppBar, so the
                // section header doubles as its page title.
                DashboardSectionHeader(title: l10n.live),
                for (var i = 0; i < classes.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FadeSlideIn(
                      delay: i < 12 ? Duration(milliseconds: 40 * i) : Duration.zero,
                      child: AppListCard(
                        leading: AppListBadge(text: '${classes[i].grade}'),
                        title: classes[i].name,
                        subtitle: '${countByClass[classes[i].id] ?? 0} ${l10n.students}',
                        trailing: _CameraStatus(
                          hasCamera: classIdsWithCamera.contains(classes[i].id),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClassLiveAttendanceScreen(
                              classId: classes[i].id,
                              className: classes[i].name,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );

    // Embedded as a MainScreen tab this renders without an AppBar of its
    // own, so nothing else keeps the list out from under the status bar --
    // hence the explicit top inset. Bottom stays unpadded on purpose: the
    // list is meant to scroll under the floating nav pill and fade out.
    return widget.isIntegrated
        ? SafeArea(bottom: false, child: body)
        : AppShell(title: l10n.live, child: body);
  }
}

/// Whether a class has a camera feeding live attendance -- a class without
/// one can still be opened, it just won't have anything to show, so this
/// reads as a quiet status rather than an error.
class _CameraStatus extends StatelessWidget {
  const _CameraStatus({required this.hasCamera});

  final bool hasCamera;

  @override
  Widget build(BuildContext context) {
    final color = hasCamera ? context.colors.success : context.colors.textMuted;
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: AppRadius.smRadius,
      ),
      child: Icon(
        hasCamera ? Icons.videocam_rounded : Icons.videocam_off_outlined,
        color: color,
        size: 17,
      ),
    );
  }
}
