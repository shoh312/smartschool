import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
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
          const SizedBox(height: 28),
          Text(
            l10n.quickActions,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DashboardAction(
                  icon: Icons.analytics_outlined,
                  label: l10n.history,
                  route: AppRoutes.attendanceHistory,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardAction(
                  icon: Icons.live_tv_rounded,
                  label: l10n.liveStream,
                  route: AppRoutes.liveAttendance,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardAction(
                  icon: Icons.grade_outlined,
                  label: l10n.grades,
                  route: AppRoutes.schoolJournal,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            l10n.recentActivity,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          if (live.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  l10n.noAttendanceRecorded,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...live.take(10).map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.lgRadius,
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadows.card,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          borderRadius: AppRadius.mdRadius,
                        ),
                        child: Center(
                          child: Text(
                            item.fullName.isEmpty ? '?' : item.fullName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        item.fullName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
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
    required this.color,
  });

  final IconData icon;
  final String label;
  final String route;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppGradients.tint(color),
                  borderRadius: AppRadius.mdRadius,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
