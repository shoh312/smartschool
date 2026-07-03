import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/student_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/app_shell.dart';
import '../widgets/metric_card.dart';
import '../widgets/status_chip.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

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
      final attendance = context.read<AttendanceProvider>();
      attendance.loadLive();
      attendance.startRealtime();
    });
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final l10n = AppLocalizations.of(context)!;

    final live = attendance.live;
    int count(AttendanceStatus status) =>
        live.where((item) => item.status == status).length;

    Widget body = RefreshIndicator(
      onRefresh: () async {
        await students.loadStudents();
        await attendance.loadLive();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 700 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5, // Changed from 2.2 to 1.5 for more height
                children: [
                  MetricCard(
                    label: l10n.students,
                    value: students.students.length.toString(),
                    icon: Icons.groups_outlined,
                  ),
                  MetricCard(
                    label: l10n.present,
                    value: count(AttendanceStatus.present).toString(),
                    icon: Icons.check_circle_outline,
                  ),
                  MetricCard(
                    label: l10n.late,
                    value: count(AttendanceStatus.late).toString(),
                    icon: Icons.schedule,
                  ),
                  MetricCard(
                    label: l10n.absent,
                    value: count(AttendanceStatus.absent).toString(),
                    icon: Icons.cancel_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            l10n.quickActions,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DashboardAction(
                icon: Icons.analytics_outlined,
                label: l10n.history,
                route: AppRoutes.attendanceHistory,
              ),
              _DashboardAction(
                icon: Icons.live_tv,
                label: l10n.liveStream,
                route: AppRoutes.liveAttendance,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            l10n.recentActivity,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (live.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(l10n.noAttendanceRecorded)),
              ),
            )
          else
            ...live.take(10).map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(item.fullName[0]),
                      ),
                      title: Text(item.fullName),
                      subtitle: Text(l10n.cameraLabel(item.cameraId?.toString() ?? '-')),
                      trailing: AttendanceStatusChip(status: item.status),
                    ),
                  ),
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

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () => Navigator.pushNamed(context, route),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
