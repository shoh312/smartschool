import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/app_role.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/bottom_nav_inset.dart';
import 'change_password_screen.dart';
import 'settings_screen.dart';

/// Who you are signed in as, and everything that follows from it.
///
/// Sits where Settings used to sit in the bottom bar, with Settings one tap
/// inside. Nobody looks for "settings" to answer "whose session is this" or
/// "how do I sign out" -- they look for themselves, and the rest hangs off
/// that.
///
/// The name and its second line come from the session rather than a
/// request: every login response already carries them (see TokenStorage),
/// so this screen has nothing to load and nothing to fail at.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
  }

  String _roleLabel(AppLocalizations l10n, AppRole? role) => switch (role) {
        AppRole.director => l10n.roleDirector,
        AppRole.teacher => l10n.roleTeacher,
        AppRole.parent => l10n.roleParent,
        AppRole.student => l10n.roleStudent,
        null => '',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: (const EdgeInsets.fromLTRB(20, 20, 20, 24))
            .add(bottomNavPadding(context)),
        children: [
          _IdentityCard(
            initials: _initials(auth.displayName),
            name: auth.displayName ?? _roleLabel(l10n, auth.role),
            role: _roleLabel(l10n, auth.role),
            detail: auth.displayDetail,
          ),
          const SizedBox(height: 26),
          _Group(
            children: [
              _Row(
                icon: Icons.tune_rounded,
                label: l10n.settings,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              // Only the director has a password endpoint today. Showing the
              // row to a teacher would open a form that cannot succeed --
              // worse than not offering it, because it looks like their
              // fault when it fails.
              if (auth.role == AppRole.director) ...[
                const _Separator(),
                _Row(
                  icon: Icons.lock_outline_rounded,
                  label: l10n.passwordChangeTitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(forced: false),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _Group(
            children: [
              _Row(
                icon: Icons.logout_rounded,
                label: l10n.logout,
                color: context.colors.danger,
                showChevron: false,
                onTap: () => _confirmLogout(context, l10n),
              ),
            ],
          ),
        ],
      ),
    );
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
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.initials,
    required this.name,
    required this.role,
    this.detail,
  });

  final String initials;
  final String name;
  final String role;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppShadows.colored(context.colors.primary),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                if (detail != null && detail!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 56, color: context.colors.border);
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color ?? context.colors.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: tint,
                ),
              ),
            ),
            if (showChevron)
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: context.colors.textMuted),
          ],
        ),
      ),
    );
  }
}
