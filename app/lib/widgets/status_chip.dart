import 'package:flutter/material.dart';
import '../models/attendance.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

class AttendanceStatusChip extends StatelessWidget {
  const AttendanceStatusChip({super.key, required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    final color = switch (status) {
      AttendanceStatus.present => const Color(0xFF10B981), // Emerald
      AttendanceStatus.absent => const Color(0xFFEF4444), // Red
      AttendanceStatus.late => const Color(0xFFF59E0B), // Amber
      AttendanceStatus.leftSchool => const Color(0xFF6366F1), // Indigo
      AttendanceStatus.notDetected => Colors.grey,
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
