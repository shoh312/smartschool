import 'package:flutter/material.dart';

import '../models/student.dart';
import '../routes/app_routes.dart';

import 'package:smartschool_app/generated/app_localizations.dart';

class StudentTile extends StatelessWidget {
  const StudentTile({
    super.key,
    required this.student,
    this.onEdit,
    this.onDelete,
  });

  final Student student;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              student.firstName.isEmpty ? '?' : student.firstName[0].toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(
          student.fullName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            l10n.classTileLabel(student.className ?? student.classId?.toString() ?? 'N/A'),
            style: theme.textTheme.bodySmall,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: Icon(Icons.edit_note_rounded, size: 22, color: Colors.grey.shade600),
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 22, color: Color(0xFFEF4444)),
                onPressed: onDelete,
              ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.studentDetails,
          arguments: student,
        ),
      ),
    );
  }
}
