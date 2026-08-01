import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';
import '../core/design_tokens.dart';
import '../core/language_options.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/flag_badge.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langProvider = context.watch<LanguageProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              l10n.language,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.colors.textSecondary,
                    letterSpacing: 0.4,
                  ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.lgRadius,
              border: Border.all(color: context.colors.border),
              boxShadow: AppShadows.card,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final option in kLanguageOptions) ...[
                  _buildLanguageOption(context, langProvider, option),
                  if (option != kLanguageOptions.last)
                    const Divider(height: 1, indent: 68),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              l10n.appearance,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.colors.textSecondary,
                    letterSpacing: 0.4,
                  ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.lgRadius,
              border: Border.all(color: context.colors.border),
              boxShadow: AppShadows.card,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildThemeOption(
                  context,
                  themeProvider,
                  mode: ThemeMode.light,
                  icon: Icons.light_mode_outlined,
                  label: l10n.themeLight,
                ),
                const Divider(height: 1, indent: 68),
                _buildThemeOption(
                  context,
                  themeProvider,
                  mode: ThemeMode.dark,
                  icon: Icons.dark_mode_outlined,
                  label: l10n.themeDark,
                ),
                const Divider(height: 1, indent: 68),
                _buildThemeOption(
                  context,
                  themeProvider,
                  mode: ThemeMode.system,
                  icon: Icons.brightness_auto_outlined,
                  label: l10n.themeSystem,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.lgRadius,
              border: Border.all(color: context.colors.border),
              boxShadow: AppShadows.card,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _confirmLogout(context, l10n),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: context.colors.danger, size: 24),
                    const SizedBox(width: 14),
                    Text(
                      l10n.logout,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: context.colors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logout),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: dialogContext.colors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<AuthProvider>().logout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    }
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider provider, {
    required ThemeMode mode,
    required IconData icon,
    required String label,
  }) {
    final selected = provider.mode == mode;
    return InkWell(
      onTap: () => provider.setMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: context.colors.textSecondary, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
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
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    LanguageProvider provider,
    LanguageOption option,
  ) {
    final selected = provider.locale == option.locale;
    return InkWell(
      onTap: () => provider.setLocale(option.locale),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            FlagBadge(countryCode: option.countryCode, width: 36, height: 24),
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
    );
  }
}
