import 'package:flutter/material.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';

/// The app's one confirm/destructive dialog -- a normal [AlertDialog] (so it
/// inherits the app-wide `dialogTheme`: rounded corners, tokenized colors,
/// no visual reinvention) with an icon circle above the title instead of a
/// bare title+message, used for every delete/logout/remove confirmation
/// instead of each screen rolling its own plain [AlertDialog].
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final color = isDestructive ? context.colors.danger : context.colors.primary;
      return AlertDialog(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(gradient: AppGradients.tint(color), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel ?? l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel ?? l10n.delete,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
