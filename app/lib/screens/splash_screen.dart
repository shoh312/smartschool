import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../models/app_role.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import 'change_password_screen.dart';
import '../services/discovery_service.dart';
import '../services/token_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restore();
    });
  }

  Future<void> _restore() async {
    final auth = context.read<AuthProvider>();
    final tokenStorage = context.read<TokenStorage>();

    // Restoring the session is local-storage only, so doing it first is free
    // and tells us whether the LAN search below is worth running at all.
    await auth.restoreSession();

    // Both addresses are resolved together rather than one after the other:
    // each may end up scanning the subnet, and doing that twice in sequence
    // would double a wait the user is already staring at a splash for.
    await Future.wait([
      resolvePublicServerUrl(tokenStorage),
      if (roleUsesSchoolServer(auth.role)) resolveSchoolServerUrl(tokenStorage),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    if (!mounted) return;

    // A director whose session predates the forced-change rule still has a
    // valid token, so the check has to happen on restore as well as login.
    if (auth.role == AppRole.director) {
      await auth.refreshMustChangePassword();
      if (!mounted) return;
      if (auth.mustChangePassword) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
        );
        return;
      }
    }

    // Every role lands on the same tabbed shell now; which tabs it shows
    // is decided inside MainScreen from the role.
    final route = auth.role == null ? AppRoutes.login : AppRoutes.main;

    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.colored(context.colors.primary),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 72,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'SmartSchool',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PREMIUM EDITION',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.colors.primary,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 64),
              SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    backgroundColor: context.colors.surfaceSunken,
                    valueColor: AlwaysStoppedAnimation(context.colors.primary),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }
}