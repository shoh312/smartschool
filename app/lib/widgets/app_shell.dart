import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../models/app_role.dart';
import '../providers/auth_provider.dart';
import '../providers/director_nav_provider.dart';
import '../routes/app_routes.dart';
import 'director_bottom_nav.dart';

import 'package:smartschool_app/generated/app_localizations.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.showAppBar = true,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Screens embedded as a MainScreen tab already get the bottom nav from
    // MainScreen's own Scaffold; only screens pushed on top of it (not the
    // first route) need AppShell to add one, so it doesn't double up.
    final isPushedScreen = !(ModalRoute.of(context)?.isFirst ?? true);
    final isDirector = context.watch<AuthProvider>().role == AppRole.director;
    final showBottomNav = isDirector && isPushedScreen;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(title),
              actions: [
                ...actions,
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: l10n.signOutTooltip,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceAlt,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    onPressed: () async {
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                          (_) => false,
                        );
                      }
                    },
                  ),
                ),
              ],
            )
          : null,
      body: SafeArea(child: child),
      bottomNavigationBar: showBottomNav
          ? DirectorBottomNav(
              selectedIndex: context.watch<DirectorNavProvider>().currentIndex,
              onDestinationSelected: (index) => selectDirectorTab(context, index),
            )
          : null,
    );
  }
}
