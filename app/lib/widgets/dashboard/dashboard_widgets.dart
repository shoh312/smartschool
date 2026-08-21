import 'package:flutter/material.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../../core/design_tokens.dart';

/// Section heading used to break a long dashboard into named groups
/// ("Learning", "School") instead of one undifferentiated tile grid.
class DashboardSectionHeader extends StatelessWidget {
  const DashboardSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// The dashboard's single headline figure: how much of the school has
/// actually turned up today, as a ring plus the present/late/absent split.
///
/// Replaces a row of four equal-weight metric tiles -- those gave the
/// headline number no more prominence than its own breakdown, so nothing
/// on the screen answered "how is today going?" at a glance.
class AttendanceHeroCard extends StatelessWidget {
  const AttendanceHeroCard({
    super.key,
    required this.total,
    required this.present,
    required this.late,
    required this.absent,
  });

  final int total;
  final int present;
  final int late;
  final int absent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final arrived = present + late;
    final ratio = total == 0 ? 0.0 : (arrived / total).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: AppRadius.xlRadius,
        boxShadow: AppShadows.colored(context.colors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 62,
                height: 62,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.white.withOpacity(0.22),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.attendanceToday,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.arrivedOfTotal(arrived, total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroStat(label: l10n.present, value: present),
              _HeroDivider(),
              _HeroStat(label: l10n.late, value: late),
              _HeroDivider(),
              _HeroStat(label: l10n.absent, value: absent),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withOpacity(0.18),
    );
  }
}

/// One class's turnout: grade badge, name, roll size, and a progress bar --
/// the bar makes a whole column of classes comparable at a glance, which a
/// bare "24/28" label on its own does not.
class ClassAttendanceCard extends StatelessWidget {
  const ClassAttendanceCard({
    super.key,
    required this.grade,
    required this.name,
    required this.total,
    required this.arrived,
    required this.present,
    required this.late,
    required this.absent,
    required this.onTap,
  });

  final int grade;
  final String name;
  final int total;
  final int arrived;
  final int present;
  final int late;
  final int absent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ratio = total == 0 ? 0.0 : (arrived / total).clamp(0.0, 1.0);
    final barColor = total == 0
        ? context.colors.textMuted
        : arrived == total
            ? context.colors.success
            : arrived == 0
                ? context.colors.danger
                : context.colors.warning;

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.lgRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: AppGradients.tint(context.colors.primary),
                      borderRadius: AppRadius.mdRadius,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$grade',
                      style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$total ${l10n.students}',
                          style: TextStyle(color: context.colors.textMuted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$arrived/$total',
                    style: TextStyle(
                      color: barColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 20, color: context.colors.textMuted),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: context.colors.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Dot(label: l10n.present, value: present, color: context.colors.success),
                  const SizedBox(width: 14),
                  _Dot(label: l10n.late, value: late, color: context.colors.warning),
                  const SizedBox(width: 14),
                  _Dot(label: l10n.absent, value: absent, color: context.colors.danger),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$value',
          style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(color: context.colors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}
