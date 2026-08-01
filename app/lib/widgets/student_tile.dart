import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
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
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.studentDetails,
            arguments: student,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: AppRadius.mdRadius,
                boxShadow: AppShadows.colored(context.colors.primary),
              ),
              child: Center(
                child: Text(
                  student.firstName.isEmpty ? '?' : student.firstName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            title: Text(
              student.fullName,
              style: theme.textTheme.titleMedium,
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
                    icon: Icon(Icons.edit_note_rounded, size: 22, color: context.colors.textMuted),
                    onPressed: onEdit,
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, size: 22, color: context.colors.danger),
                    onPressed: onDelete,
                  ),
                Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
