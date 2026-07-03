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

class LiveAttendanceScreen extends StatefulWidget {
  const LiveAttendanceScreen({super.key, this.isIntegrated = false, this.cameraId});

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
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(item.fullName),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: MjpegPlayer(url: AppConstants.liveStreamUrl(cameraId: _cameraId)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      child: Text(
                        '${item.firstName[0]}${item.lastName[0]}',
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(item.fullName, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    AttendanceStatusChip(status: item.status),
                  ],
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
    final provider = context.watch<AttendanceProvider>();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
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
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          item.status == AttendanceStatus.present
                              ? Icons.check_circle
                              : Icons.person_outline,
                          color: item.status == AttendanceStatus.present
                              ? Colors.green
                              : null,
                        ),
                        title: Text(item.fullName),
                        subtitle: Text(
                          l10n.lastSeenTime(DateFormatters.time(item.lastSeen)),
                        ),
                        trailing: AttendanceStatusChip(status: item.status),
                        onTap: () => _showStudentFullScreen(item),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    return widget.isIntegrated ? body : AppShell(
      title: studentId == null ? l10n.live : l10n.liveStatus,
      child: body,
    );
  }
}
