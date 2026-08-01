import 'package:flutter/material.dart';
import '../core/design_tokens.dart';
import '../models/attendance.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

class AttendanceStatusChip extends StatelessWidget {
  const AttendanceStatusChip({super.key, required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final color = switch (status) {
      AttendanceStatus.present => context.colors.success,
      AttendanceStatus.absent => context.colors.danger,
      AttendanceStatus.late => context.colors.warning,
      AttendanceStatus.leftSchool => context.colors.primary,
      AttendanceStatus.notDetected => context.colors.textMuted,
    };

    final label = switch (status) {
      AttendanceStatus.present => l10n.present,
      AttendanceStatus.absent => l10n.absent,
      AttendanceStatus.late => l10n.late,
      AttendanceStatus.leftSchool => l10n.leftSchool,
      AttendanceStatus.notDetected => l10n.notDetected,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppRadius.smRadius,
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
