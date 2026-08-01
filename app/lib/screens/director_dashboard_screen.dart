import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/school_provider.dart';
import '../providers/student_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/app_shell.dart';
import '../widgets/metric_card.dart';
import 'package:smartschool_app/generated/app_localizations.dart';
import 'class_attendance_analytics_screen.dart';

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
      context.read<SchoolProvider>().loadSchoolData();
      final attendance = context.read<AttendanceProvider>();
      attendance.loadLive();
      attendance.startRealtime();
    });
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final school = context.watch<SchoolProvider>();
    final l10n = AppLocalizations.of(context)!;

    final live = attendance.live;
    int count(AttendanceStatus status) =>
        live.where((item) => item.status == status).length;

    final studentsById = {
      for (final student in students.students) student.id: student,
    };
    final totalByClass = <int, int>{};
    for (final student in students.students) {
      final classId = student.classId;
      if (classId == null) continue;
      totalByClass[classId] = (totalByClass[classId] ?? 0) + 1;
    }
    const arrivedStatuses = {
      AttendanceStatus.present,
      AttendanceStatus.late,
      AttendanceStatus.leftSchool,
    };
    final arrivedByClass = <int, int>{};
    final presentByClass = <int, int>{};
    final lateByClass = <int, int>{};
    final absentByClass = <int, int>{};
    for (final item in live) {
      final classId = studentsById[item.studentId]?.classId;
      if (classId == null) continue;
      if (arrivedStatuses.contains(item.status)) {
        arrivedByClass[classId] = (arrivedByClass[classId] ?? 0) + 1;
      }
      switch (item.status) {
        case AttendanceStatus.present:
          presentByClass[classId] = (presentByClass[classId] ?? 0) + 1;
        case AttendanceStatus.late:
          lateByClass[classId] = (lateByClass[classId] ?? 0) + 1;
        case AttendanceStatus.absent:
          absentByClass[classId] = (absentByClass[classId] ?? 0) + 1;
        default:
          break;
      }
    }

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
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 100,
                ),
                children: [
                  MetricCard(
                    label: l10n.students,
                    value: students.students.length.toString(),
                    imageAsset: 'assets/icons/students.png',
                  ),
                  MetricCard(
                    label: l10n.present,
                    value: count(AttendanceStatus.present).toString(),
                    imageAsset: 'assets/icons/present.png',
                  ),
                  MetricCard(
                    label: l10n.late,
                    value: count(AttendanceStatus.late).toString(),
                    imageAsset: 'assets/icons/late.png',
                  ),
                  MetricCard(
                    label: l10n.absent,
                    value: count(AttendanceStatus.absent).toString(),
                    imageAsset: 'assets/icons/absent.png',
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
                  imageAsset: 'assets/icons/history.png',
                  label: l10n.history,
                  route: AppRoutes.attendanceHistory,
                  color: context.colors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardAction(
                  imageAsset: 'assets/icons/live_stream.png',
                  label: l10n.liveStream,
                  route: AppRoutes.liveAttendance,
                  color: context.colors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardAction(
                  imageAsset: 'assets/icons/grades.png',
                  label: l10n.grades,
                  route: AppRoutes.schoolJournal,
                  color: context.colors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            l10n.attendanceByClass,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          if (school.classes.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadius.lgRadius,
                border: Border.all(color: context.colors.border),
              ),
              child: Center(
                child: Text(
                  l10n.noClasses,
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ),
            )
          else
            ...(List.of(school.classes)
                  ..sort((a, b) {
                    final byGrade = a.grade.compareTo(b.grade);
                    return byGrade != 0 ? byGrade : a.name.compareTo(b.name);
                  }))
                .map((schoolClass) {
              final total = totalByClass[schoolClass.id] ?? 0;
              final arrived = arrivedByClass[schoolClass.id] ?? 0;
              final present = presentByClass[schoolClass.id] ?? 0;
              final late = lateByClass[schoolClass.id] ?? 0;
              final absentCount = absentByClass[schoolClass.id] ?? 0;
              final ratioColor = total == 0
                  ? context.colors.textMuted
                  : arrived == total
                  ? context.colors.success
                  : arrived == 0
                  ? context.colors.textMuted
                  : context.colors.warning;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: AppRadius.lgRadius,
                  border: Border.all(color: context.colors.border),
                  boxShadow: AppShadows.card,
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClassAttendanceAnalyticsScreen(
                        schoolClass: schoolClass,
                      ),
                    ),
                  ),
                  child: Column(
                  children: [
                  ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: AppRadius.mdRadius,
                    ),
                    child: Center(
                      child: Text(
                        schoolClass.grade.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    schoolClass.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: Text('$total ${l10n.students}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ratioColor.withOpacity(0.12),
                      borderRadius: AppRadius.smRadius,
                      border: Border.all(color: ratioColor.withOpacity(0.18)),
                    ),
                    child: Text(
                      '$arrived/$total',
                      style: TextStyle(
                        color: ratioColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(
                      children: [
                        _InlineStat(label: l10n.present, value: present, color: context.colors.success),
                        const SizedBox(width: 16),
                        _InlineStat(label: l10n.late, value: late, color: context.colors.warning),
                        const SizedBox(width: 16),
                        _InlineStat(label: l10n.absent, value: absentCount, color: context.colors.danger),
                      ],
                    ),
                  ),
                  ],
                  ),
                  ),
                  ),
                  );
            }),
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
    this.icon,
    this.imageAsset,
    required this.label,
    required this.route,
    required this.color,
  }) : assert(icon != null || imageAsset != null, 'Provide icon or imageAsset');

  final IconData? icon;
  final String? imageAsset;
  final String label;
  final String route;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: context.colors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              if (imageAsset != null)
                Image.asset(imageAsset!, width: 40, height: 40)
              else
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
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$value',
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
