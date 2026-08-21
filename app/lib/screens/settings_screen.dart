import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';
import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../core/language_options.dart';
import '../models/app_role.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../services/token_storage.dart';
import '../routes/app_routes.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/flag_badge.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langProvider = context.watch<LanguageProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDirector = context.watch<AuthProvider>().role == AppRole.director;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: (const EdgeInsets.fromLTRB(20, 20, 20, 24)).add(bottomNavPadding(context)),
        children: [
          DashboardSectionHeader(title: l10n.language),
          Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.lgRadius,
              border: Border.all(color: context.colors.border),
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
          const SizedBox(height: 26),
          DashboardSectionHeader(title: l10n.appearance),
          Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.lgRadius,
              border: Border.all(color: context.colors.border),
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
          const SizedBox(height: 26),
          // The address only ever needs touching when the school is being set
          // up or moved, which is the director's job. Everyone else's app
          // reaches the Public Server at the address it was built with, and
          // handing them a field that can break every screen buys nothing.
          if (isDirector) ...[
            DashboardSectionHeader(title: l10n.serverAddress),
            Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadius.lgRadius,
                border: Border.all(color: context.colors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _editServerAddress(context, l10n),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.dns_outlined, color: context.colors.textSecondary, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          l10n.serverAddressCurrent(AppConstants.publicServerBaseUrl),
                          style: TextStyle(
                            fontSize: 13.5,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: context.colors.textMuted, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
          ],
          // Directors are the only role with a password of their own to
          // change here; the others are issued theirs by the school.
          if (isDirector) ...[
            Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadius.lgRadius,
                border: Border.all(color: context.colors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(forced: false),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          color: context.colors.textSecondary, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          l10n.passwordChangeTitle,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: context.colors.textMuted, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.lgRadius,
              border: Border.all(color: context.colors.border),
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

  /// Lets the address be corrected on the device instead of in a rebuild.
  ///
  /// The Public Server is not on the LAN, so nothing can discover it; when
  /// its host or domain changes, this is what keeps the installed app
  /// working without reinstalling it on every phone.
  Future<void> _editServerAddress(BuildContext context, AppLocalizations l10n) async {
    final controller = TextEditingController(
      text: AppConstants.publicServerBaseUrl,
    );
    final storage = context.read<TokenStorage>();

    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(l10n.serverAddress),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'https://...'),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.serverAddressHint,
              style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (saved == null) return;

    final trimmed = saved.trim();
    // Empty means "go back to the address built into this APK".
    await storage.savePublicServerUrl(
      trimmed == AppConstants.defaultPublicServerBaseUrl ? null : trimmed,
    );
    AppConstants.setPublicServerBaseUrl(trimmed);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.serverAddressSaved)));
  }

  Future<void> _confirmLogout(BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.logout_rounded,
      title: l10n.logout,
      message: l10n.logoutConfirmMessage,
      confirmLabel: l10n.logout,
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) return;

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
