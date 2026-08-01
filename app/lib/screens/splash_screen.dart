import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../models/app_role.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
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

    await Future.wait([
      _resolveServerUrl(tokenStorage),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);
    await auth.restoreSession();

    if (!mounted) return;

    final route = switch (auth.role) {
      AppRole.director => AppRoutes.main,
      AppRole.parent => AppRoutes.parentDashboard,
      AppRole.teacher => AppRoutes.teacherDashboard,
      null => AppRoutes.login,
    };

    Navigator.pushReplacementNamed(context, route);
  }

  /// Finds the backend on the current network: try the last known-good
  /// address first (fast path, no traffic if it still works), and only fall
  /// back to a broadcast search if that fails or nothing was cached yet.
  Future<void> _resolveServerUrl(TokenStorage tokenStorage) async {
    final discovery = DiscoveryService();
    final cachedUrl = await tokenStorage.readServerUrl();

    if (cachedUrl != null && await discovery.isReachable(cachedUrl)) {
      AppConstants.setResolvedBaseUrl(cachedUrl);
      return;
    }

    final discoveredUrl = await discovery.discoverBaseUrl();
    if (discoveredUrl != null) {
      AppConstants.setResolvedBaseUrl(discoveredUrl);
      await tokenStorage.saveServerUrl(discoveredUrl);
    }
    // If discovery also fails, AppConstants just keeps its hardcoded fallback.
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