import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../models/attendance.dart';
import '../models/camera_config.dart';
import '../providers/attendance_provider.dart';
import '../providers/school_provider.dart';
import '../utils/date_formatters.dart';
import '../widgets/app_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/mjpeg_player.dart';
import '../widgets/status_chip.dart';
import '../core/constants.dart';
import '../core/design_tokens.dart';

class LiveAttendanceScreen extends StatefulWidget {
  const LiveAttendanceScreen({
    super.key,
    this.isIntegrated = false,
    this.cameraId,
  });

  final bool isIntegrated;
  final int? cameraId;

  @override
  State<LiveAttendanceScreen> createState() => _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends State<LiveAttendanceScreen> {
  List<CameraConfig> _cameras = [];
  int _selectedCameraId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final school = context.read<SchoolProvider>();
      if (school.cameras.isEmpty) await school.loadSchoolData();
      _cameras = school.cameras.where((c) => c.isActive).toList();
      if (_cameras.isNotEmpty) {
        _selectedCameraId = _cameras.first.id;
        if (mounted) setState(() {});
      }

      final classId = _cameras.isNotEmpty ? _cameras.first.classId : null;
      final att = context.read<AttendanceProvider>();
      await att.loadLive(classId: classId);
      att.startRealtime(classId: classId);
    });
  }

  int get _cameraId => _selectedCameraId;

  void _showStudentFullScreen(LiveAttendance item) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, __) => FadeTransition(
          opacity: animation,
          child: _LiveVideoView(item: item, cameraId: _cameraId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final studentId = args?['studentId'] as int?;
    final l10n = AppLocalizations.of(context)!;

    final displayList = studentId == null
        ? provider.live
        : provider.live.where((item) => item.studentId == studentId).toList();

    final body = Column(
      children: [
        Expanded(
          child: provider.isLoading && displayList.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : displayList.isEmpty
              ? EmptyState(
                  icon: Icons.live_tv,
                  title: l10n.noLiveData,
                  message: l10n.realtimeAttendanceMessage,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = displayList[index];
                    final isPresent = item.status == AttendanceStatus.present;
                    final accent = isPresent
                        ? AppColors.success
                        : AppColors.textMuted;
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.lgRadius,
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.card,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showStudentFullScreen(item),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: AppGradients.tint(accent),
                                borderRadius: AppRadius.mdRadius,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                isPresent
                                    ? Icons.check_circle_rounded
                                    : Icons.person_outline_rounded,
                                color: accent,
                              ),
                            ),
                            title: Text(
                              item.fullName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              l10n.lastSeenTime(
                                DateFormatters.time(item.lastSeen),
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: AttendanceStatusChip(status: item.status),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    return widget.isIntegrated
        ? body
        : AppShell(
            title: studentId == null ? l10n.live : l10n.liveStatus,
            child: body,
          );
  }
}

/// Full-bleed, immersive live-camera viewer: video fills the whole screen,
/// info (name, last seen, status) sits in a single overlay at the bottom
/// instead of being repeated in a header too. Tap the video to hide/show
/// the overlays for an unobstructed view.
class _LiveVideoView extends StatefulWidget {
  const _LiveVideoView({required this.item, required this.cameraId});

  final LiveAttendance item;
  final int cameraId;

  @override
  State<_LiveVideoView> createState() => _LiveVideoViewState();
}

class _LiveVideoViewState extends State<_LiveVideoView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final item = widget.item;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MjpegPlayer(
              url: AppConstants.liveStreamUrl(cameraId: widget.cameraId),
            ),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Stack(
                  children: [
                    // Top scrim: back button + pulsing LIVE badge.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(8, topInset + 8, 12, 28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.smRadius,
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            FadeTransition(
                              opacity: Tween<double>(
                                begin: 0.35,
                                end: 1,
                              ).animate(_pulseController),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  borderRadius: AppRadius.smRadius,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'LIVE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bottom scrim: single info card (avatar, name, last
                    // seen, status) -- shown once, not repeated up top.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          40,
                          16,
                          bottomInset + 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.78),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                gradient: AppGradients.primary,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${item.firstName[0]}${item.lastName[0]}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.fullName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.lastSeenTime(
                                      DateFormatters.time(item.lastSeen),
                                    ),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.65),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            AttendanceStatusChip(status: item.status),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
