import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/student_provider.dart';
import '../services/school_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/live_charts.dart';

/// The director's dashboard on a desktop, where the screen is wide enough to
/// show the whole school at once.
///
/// The phone gets the plain list of shortcuts: it is held at arm's length,
/// for a minute, to answer one question. A desktop in the office is left
/// open all morning, so it is worth showing the shape of the day rather than
/// a number that has to be tapped to be found -- who has arrived, when they
/// arrived, and which class is missing people.
///
/// Live throughout: the same websocket that drives the attendance screen
/// pushes every recognition here as it happens, so nothing has to be
/// refreshed by hand.
class WindowsDashboardScreen extends StatefulWidget {
  const WindowsDashboardScreen({super.key, this.isIntegrated = false});

  final bool isIntegrated;

  @override
  State<WindowsDashboardScreen> createState() => _WindowsDashboardScreenState();
}

class _WindowsDashboardScreenState extends State<WindowsDashboardScreen> {
  // A desktop reader expects a scrollbar to be there, not to appear once
  // they have already started scrolling and discovered there is more.
  final _scrollController = ScrollController();

  /// Null until the school's own setting has been read. The panel below
  /// behaves differently in the two modes, and guessing before the answer
  /// arrives would make it flip once it does.
  bool? _groupMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final attendance = context.read<AttendanceProvider>();
      context.read<StudentProvider>().loadStudents();
      await attendance.loadLive();
      if (mounted) attendance.startRealtime();
      try {
        final settings = await context.read<SchoolService>().fetchSettings();
        if (mounted) setState(() => _groupMode = settings.groupMode);
      } catch (_) {
        // Unreadable setting falls back to the school layout, which shows
        // every class -- the worse failure would be hiding classes from a
        // school that has no lesson windows at all.
        if (mounted) setState(() => _groupMode = false);
      }
    });
  }

  @override
  void dispose() {
    // The socket is shared, so it is stopped rather than left listening to a
    // screen that no longer exists.
    context.read<AttendanceProvider>().stopRealtime();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final students = context.watch<StudentProvider>();
    final colors = context.colors;

    final live = attendance.live;
    final counts = _countByStatus(live);
    final present = counts[AttendanceStatus.present] ?? 0;
    final late = counts[AttendanceStatus.late] ?? 0;
    final absent = counts[AttendanceStatus.absent] ?? 0;
    final pending = counts[AttendanceStatus.notDetected] ?? 0;
    final left = counts[AttendanceStatus.leftSchool] ?? 0;
    final arrived = present + late + left;
    final total = live.isEmpty ? students.students.length : live.length;

    final body = Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView(
        controller: _scrollController,
        // The bottom nav is a floating pill the body runs underneath, so the
        // last row needs clearance to scroll out from behind it. Without this
        // the list ended under the pill and looked like it would not scroll at
        // all.
        padding: const EdgeInsets.fromLTRB(
          28,
          24,
          28,
          32,
        ).add(bottomNavPadding(context)),
        children: [
          // The headline number and the split it breaks down into, in one
          // card. They were two blocks with a gap between them, which spent
          // the top third of the screen saying one thing twice.
          _Card(
            title: 'Bugungi holat',
            leading: _Headline(arrived: arrived, total: total),
            child: AttendanceSplitBar(
              slices: [
                StatusSlice(
                  label: 'keldi',
                  count: present,
                  color: colors.success,
                  icon: Icons.check_circle_rounded,
                ),
                StatusSlice(
                  label: 'kech qoldi',
                  count: late,
                  color: colors.warning,
                  icon: Icons.schedule_rounded,
                ),
                StatusSlice(
                  label: 'kelmadi',
                  count: absent,
                  color: colors.danger,
                  icon: Icons.cancel_rounded,
                ),
                StatusSlice(
                  label: 'kutilmoqda',
                  count: pending,
                  color: colors.textMuted,
                  icon: Icons.hourglass_empty_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Two panels side by side on a wide window, stacked when it is
          // narrow. Only the layout responds to width -- never the chrome.
          LayoutBuilder(
            builder: (context, constraints) {
              final timeline = _Card(
                title: 'Kelish vaqti',
                subtitle: 'kun boshidan hozirgacha to\'plangan',
                child: ArrivalTimelineChart(
                  points: _arrivalCurve(live),
                  total: total,
                ),
              );
              // Two different panels, because the two schools ask different
              // questions of it. A school wants the whole roll, all day. An
              // academy wants the room in front of it right now.
              final groupMode = _groupMode ?? false;
              final classes = _Card(
                title: groupMode ? 'Hozirgi guruhlar' : 'Sinflar bo\'yicha',
                subtitle: groupMode
                    ? 'darsi ketayotganlar'
                    : 'eng ko\'p yetishmayotgani yuqorida',
                child: ClassAttendanceBars(
                  rows: _byClass(live, groupMode: groupMode),
                  emptyMessage: groupMode
                      ? 'Hozir darsi ketayotgan guruh yo\'q'
                      : 'Sinf ma\'lumoti kelmadi',
                ),
              );

              if (constraints.maxWidth < 900) {
                return Column(
                  children: [timeline, const SizedBox(height: 18), classes],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: timeline),
                  const SizedBox(width: 18),
                  Expanded(flex: 2, child: classes),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _Card(
            title: 'So\'nggi kelganlar',
            child: _RecentArrivals(live: live),
          ),
        ],
      ),
    );

    if (widget.isIntegrated) return body;
    return AppShell(title: 'Boshqaruv paneli', child: body);
  }

  Map<AttendanceStatus, int> _countByStatus(List<LiveAttendance> live) {
    final counts = <AttendanceStatus, int>{};
    for (final row in live) {
      counts[row.status] = (counts[row.status] ?? 0) + 1;
    }
    return counts;
  }

  /// The curve is built from the arrival times themselves rather than from
  /// fixed buckets, so a morning with three arrivals draws three steps
  /// instead of a flat line with three bumps hidden in it.
  List<ArrivalPoint> _arrivalCurve(List<LiveAttendance> live) {
    // last_seen is the fallback: a pupil marked present from the journal
    // rather than by the camera carries no arrival time, and dropping them
    // left this panel saying nobody had come while the header said thirty
    // -one had.
    final times =
        live
            .where(_hasArrived)
            .map((row) => row.arrivedAt)
            .whereType<DateTime>()
            .toList()
          ..sort();
    if (times.isEmpty) return const [];

    final points = <ArrivalPoint>[ArrivalPoint(times.first, 0)];
    for (var i = 0; i < times.length; i++) {
      points.add(ArrivalPoint(times[i], i + 1));
    }
    return points;
  }

  /// Grouped from the live feed's own class names.
  ///
  /// It used to join against the separately loaded pupil list, and the two
  /// disagreed: two hundred pupils in the feed, a hundred of them missing
  /// from that list, so every class read 0 present while the header counted
  /// thirty-one. A number that contradicts the number above it is worse than
  /// no number at all.
  List<ClassAttendance> _byClass(
    List<LiveAttendance> live, {
    required bool groupMode,
  }) {
    const noClass = 'Sinfsiz';
    final totals = <String, int>{};
    final here = <String, int>{};
    for (final row in live) {
      // In group mode only the groups whose lesson is running right now.
      // An academy runs several groups through a room in a day, and one
      // that finished at four has nothing to say about six o'clock -- it
      // would just sit there at 0 present, looking like an absence.
      //
      // A school keeps every class listed all day: its classes are in the
      // building whether or not a particular period is running.
      if (groupMode && !row.classInSession) continue;

      // Pupils with no class are counted under their own heading rather
      // than dropped. Dropping them made this panel add up to a hundred and
      // eighteen under a header counting two hundred and thirty-one, and
      // every class read 0 present while thirty-one pupils had arrived --
      // because those thirty-one were the ones being dropped.
      final name = (row.className == null || row.className!.isEmpty)
          ? noClass
          : row.className!;
      totals[name] = (totals[name] ?? 0) + 1;
      if (_hasArrived(row)) here[name] = (here[name] ?? 0) + 1;
    }

    return [
      for (final entry in totals.entries)
        ClassAttendance(
          name: entry.key,
          present: here[entry.key] ?? 0,
          total: entry.value,
        ),
    ];
  }

  static bool _hasArrived(LiveAttendance row) =>
      row.status == AttendanceStatus.present ||
      row.status == AttendanceStatus.late ||
      row.status == AttendanceStatus.leftSchool;
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    this.subtitle,
    this.leading,
    required this.child,
  });

  final String title;
  final String? subtitle;

  /// Sits on the title row, right of the heading. Lets the headline figure
  /// share a card with the breakdown it belongs to instead of floating in
  /// its own block above it.
  final Widget? leading;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12, color: colors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (leading != null) leading!,
            ],
          ),
          SizedBox(height: leading == null ? 16 : 14),
          child,
        ],
      ),
    );
  }
}

/// The day in one line, beside the breakdown rather than above it.
class _Headline extends StatelessWidget {
  const _Headline({required this.arrived, required this.total});

  final int arrived;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final percent = total == 0 ? 0 : (arrived * 100 / total).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Proportional figures on purpose: equal-width digits make a
        // display-size number look loose.
        Text(
          '$arrived',
          style: TextStyle(
            fontSize: 34,
            height: 1,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        Text(
          ' / $total',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$percent%',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentArrivals extends StatelessWidget {
  const _RecentArrivals({required this.live});

  final List<LiveAttendance> live;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Whoever arrived, with whatever time is known about them. Filtering on
    // the arrival time instead left this list empty for a school whose
    // pupils were marked present from the journal rather than by a camera.
    DateTime? when(LiveAttendance row) => row.arrivedAt;

    final arrivals =
        live
            .where(
              (row) =>
                  row.status == AttendanceStatus.present ||
                  row.status == AttendanceStatus.late ||
                  row.status == AttendanceStatus.leftSchool,
            )
            .toList()
          ..sort((a, b) {
            final at = when(a);
            final bt = when(b);
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });

    if (arrivals.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'Hali hech kim kelmadi',
            style: TextStyle(fontSize: 12.5, color: colors.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final row in arrivals.take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  row.status == AttendanceStatus.late
                      ? Icons.schedule_rounded
                      : Icons.check_circle_rounded,
                  size: 16,
                  color: row.status == AttendanceStatus.late
                      ? colors.warning
                      : colors.success,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: colors.textPrimary),
                  ),
                ),
                Text(
                  row.status == AttendanceStatus.late ? 'kech qoldi' : 'keldi',
                  style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                ),
                const SizedBox(width: 14),
                Text(
                  when(row) == null ? '—' : _clock(when(row)!),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}
