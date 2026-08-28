import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../models/camera_config.dart';
import '../providers/school_provider.dart';
import '../services/school_service.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/empty_state.dart';
import '../widgets/app_shell.dart';
import '../widgets/ws_stream_player.dart';

class ClassLiveAttendanceScreen extends StatefulWidget {
  const ClassLiveAttendanceScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  final int classId;
  final String className;

  @override
  State<ClassLiveAttendanceScreen> createState() =>
      _ClassLiveAttendanceScreenState();
}

class _ClassLiveAttendanceScreenState
    extends State<ClassLiveAttendanceScreen> {
  /// The camera the server found by looking at the room's timetable, when the
  /// class itself owns none. Null until that answer comes back -- and null
  /// forever when nothing watches this class at all.
  CameraConfig? _byPosition;
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final school = context.read<SchoolProvider>();
      if (school.cameras.isEmpty) await school.loadSchoolData();
      if (!mounted || _cameraForClass(school) != null) return;

      // Nothing is bolted to this class. In group mode that is the normal
      // case rather than a missing camera: the camera belongs to the room and
      // the timetable says whose group is in front of it, so ask the server
      // which one that is instead of showing "no camera" to a director who
      // can see the camera on the wall.
      final found = await context
          .read<SchoolService>()
          .fetchCameraForClass(widget.classId);
      if (mounted) setState(() { _byPosition = found; _asked = true; });
    });
  }

  CameraConfig? _cameraForClass(SchoolProvider school) {
    for (final camera in school.cameras) {
      if (camera.classId == widget.classId && camera.isActive) {
        return camera;
      }
    }
    return _byPosition;
  }

  @override
  Widget build(BuildContext context) {
    final school = context.watch<SchoolProvider>();
    final l10n = AppLocalizations.of(context)!;
    final camera = _cameraForClass(school);

    if (camera == null && !_asked) {
      return AppShell(
        title: widget.className,
        child: const AppLoadingIndicator(),
      );
    }

    if (camera == null) {
      return AppShell(
        title: widget.className,
        child: EmptyState(
          icon: Icons.videocam_off_outlined,
          title: l10n.noCameraForClassTitle,
          message: l10n.noCameraForClassMessage,
        ),
      );
    }

    return _ClassVideoView(className: widget.className, cameraId: camera.id);
  }
}

class _ClassVideoView extends StatefulWidget {
  const _ClassVideoView({required this.className, required this.cameraId});

  final String className;
  final int cameraId;

  @override
  State<_ClassVideoView> createState() => _ClassVideoViewState();
}

class _ClassVideoViewState extends State<_ClassVideoView>
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
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(
          fit: StackFit.expand,
          children: [
            WsStreamPlayer(
              url: AppConstants.liveStreamWebsocketUrl(cameraId: widget.cameraId),
            ),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Stack(
                  children: [
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
                    // Capped and centered so the back button/title/LIVE badge
                    // stay grouped near the (aspect-ratio-locked, so already
                    // letterboxed) video on a wide desktop window instead of
                    // spreading into a thin strip across the full width.
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.className,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                              color: context.colors.danger,
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
