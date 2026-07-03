import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';
import '../providers/language_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langProvider = context.watch<LanguageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.language, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _buildLanguageOption(context, langProvider, 'Тоҷикӣ', const Locale('tg')),
                  const Divider(height: 1),
                  _buildLanguageOption(context, langProvider, 'Русский', const Locale('ru')),
                  const Divider(height: 1),
                  _buildLanguageOption(context, langProvider, 'English', const Locale('en')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, LanguageProvider provider, String title, Locale locale) {
    return RadioListTile<Locale>(
      title: Text(title, style: const TextStyle(fontSize: 16)),
      value: locale,
      groupValue: provider.locale,
      onChanged: (Locale? value) {
        if (value != null) provider.setLocale(value);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
