import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

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
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(title),
              actions: [
                ...actions,
                IconButton(
                  tooltip: l10n.signOutTooltip,
                  icon: const Icon(Icons.logout),
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
              ],
            )
          : null,
      body: SafeArea(child: child),
    );
  }
}
