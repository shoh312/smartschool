import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';
import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../core/language_options.dart';
import '../models/app_role.dart';
import '../models/school_settings.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../services/school_service.dart';
import '../services/token_storage.dart';
import '../utils/error_formatter.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import '../widgets/flag_badge.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SchoolSettings? _school;
  bool _savingSchool = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSchoolSettings());
  }

  /// Only a director has these, and only a director's token can read
  /// them -- so a teacher opening Settings simply never sees the
  /// section rather than seeing it fail.
  Future<void> _loadSchoolSettings() async {
    if (context.read<AuthProvider>().role != AppRole.director) return;
    try {
      final settings = await context.read<SchoolService>().fetchSettings();
      if (mounted) setState(() => _school = settings);
    } catch (_) {
      // The rest of Settings works without it; the section stays hidden.
    }
  }

  Future<void> _saveSchool({bool? liveVideo, bool? groupMode}) async {
    final previous = _school;
    // Moved before the request so the switch answers the finger, not
    // the network; put back below if the server refuses.
    setState(() {
      _savingSchool = true;
      _school = _school?.copyWith(liveVideoEnabled: liveVideo, groupMode: groupMode);
    });
    try {
      final saved = await context.read<SchoolService>().updateSettings(
        liveVideoEnabled: liveVideo,
        groupMode: groupMode,
      );
      if (mounted) setState(() => _school = saved);
    } catch (exception) {
      if (!mounted) return;
      setState(() => _school = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanReadableError(classifyError(exception), AppLocalizations.of(context)!))),
      );
    } finally {
      if (mounted) setState(() => _savingSchool = false);
    }
  }

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
          // Two switches that change what the whole school sees, so they sit
          // above the address field rather than below it: this is the part a
          // director actually comes here to change.
          if (isDirector && _school != null) ...[
            DashboardSectionHeader(title: l10n.schoolSettings),
            Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadius.lgRadius,
                border: Border.all(color: context.colors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _SettingSwitch(
                    icon: Icons.videocam_outlined,
                    title: l10n.liveVideoSetting,
                    subtitle: l10n.liveVideoSettingHint,
                    value: _school!.liveVideoEnabled,
                    enabled: !_savingSchool,
                    onChanged: (value) => _saveSchool(liveVideo: value),
                  ),
                  Divider(height: 1, indent: 56, color: context.colors.border),
                  _SettingSwitch(
                    icon: Icons.groups_2_outlined,
                    title: l10n.groupModeSetting,
                    subtitle: l10n.groupModeSettingHint,
                    value: _school!.groupMode,
                    enabled: !_savingSchool,
                    onChanged: (value) => _saveSchool(groupMode: value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
          ],
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

/// One switch with its reason underneath.
///
/// The subtitle is not decoration: both of these change what other people in
/// the school can see, and a director flipping them deserves to know which
/// one does what before they find out from a teacher.
class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: enabled ? onChanged : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Icon(icon, size: 24, color: context.colors.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          color: context.colors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
      ),
    );
  }
}
