import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../core/language_options.dart';
import '../providers/language_provider.dart';
import 'flag_badge.dart';

Future<void> showLanguagePickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _LanguagePickerSheet(),
  );
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langProvider = context.watch<LanguageProvider>();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 14, left: 4),
              child: Text(l10n.language, style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final option in kLanguageOptions) ...[
              _LanguageOptionTile(
                option: option,
                selected: langProvider.locale.languageCode == option.locale.languageCode,
                onTap: () {
                  langProvider.setLocale(option.locale);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final LanguageOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.colors.primary.withOpacity(0.06) : context.colors.surfaceAlt,
      borderRadius: AppRadius.mdRadius,
      child: InkWell(
        borderRadius: AppRadius.mdRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdRadius,
            border: Border.all(
              color: selected ? context.colors.primary : context.colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              FlagBadge(countryCode: option.countryCode),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: selected ? 1 : 0,
                child: Icon(Icons.check_circle_rounded, color: context.colors.primary, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
