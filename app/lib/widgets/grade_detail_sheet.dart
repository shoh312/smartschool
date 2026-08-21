import 'package:flutter/material.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/grade.dart';

/// The chrome shared by every detail bottom sheet in the app (grade detail,
/// attendance-day detail, ...): a drag handle, rounded top container, and a
/// full-width close button -- [contentBuilder] supplies only the body in
/// between. Extracted from three near-identical `showModalBottomSheet` calls
/// that each rebuilt this same shell.
Future<void> showDetailBottomSheet(
  BuildContext context, {
  required WidgetBuilder contentBuilder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.colors.borderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              contentBuilder(context),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                ),
                child: Text(l10n.close),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Color _gradeColor(BuildContext context, int value) {
  if (value >= 9) return context.colors.success;
  if (value >= 7) return context.colors.info;
  if (value >= 5) return context.colors.warning;
  return context.colors.danger;
}

/// One grade's detail (value, subject, date, teacher, comment) -- shared by
/// `student_details_screen.dart` and `student_journal_screen.dart`, which
/// previously duplicated this content verbatim inside their own
/// `showModalBottomSheet` call. [dateLabel] is pre-formatted by the caller
/// since the two screens used slightly different date formats.
void showGradeDetailSheet(BuildContext context, {required Grade grade, required String dateLabel}) {
  showDetailBottomSheet(
    context,
    contentBuilder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final color = _gradeColor(context, grade.value);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: AppRadius.mdRadius,
                ),
                alignment: Alignment.center,
                child: Text(
                  grade.value.toString(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(grade.subject, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(l10n.journalTeacherLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(grade.teacherName ?? '-', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(l10n.journalCommentOptional, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            (grade.comment == null || grade.comment!.isEmpty) ? l10n.journalNoComment : grade.comment!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    },
  );
}
