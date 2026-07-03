import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../models/app_role.dart';
import '../providers/auth_provider.dart' as my_auth;
import '../routes/app_routes.dart';
import 'registration_details_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController(text: '+992');
  AppRole _role = AppRole.parent;
  bool _isAuthenticating = false;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<my_auth.AuthProvider>();

    if (_role == AppRole.director) {
      final success = await auth.loginDirector(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted || !success) return;
      Navigator.pushReplacementNamed(context, AppRoutes.main);
    } else if (_role == AppRole.teacher) {
      final success = await auth.loginTeacher(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted || !success) return;
      Navigator.pushReplacementNamed(context, AppRoutes.teacherDashboard);
    } else {
      // Parent Login - Bypassing OTP
      final phoneNumber = _phoneController.text.trim();
      if (phoneNumber.length < 9) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invalidPhoneError)),
        );
        return;
      }

      setState(() => _isAuthenticating = true);

      try {
        final success = await auth.loginParent(phoneNumber);
        if (success && mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.parentDashboard);
        } else if (auth.error == 'registration_required' && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegistrationDetailsScreen(phoneNumber: phoneNumber),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorPrefix(e.toString()))),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isAuthenticating = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<my_auth.AuthProvider>();
    final isLoading = auth.isLoading || _isAuthenticating;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    l10n.title,
                    style: theme.textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.login_desc,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SegmentedButton<AppRole>(
                      segments: AppRole.values
                          .map(
                            (role) => ButtonSegment(
                              value: role,
                              label: Text(switch (role) {
                                AppRole.director => l10n.roleDirector,
                                AppRole.parent => l10n.roleParent,
                                AppRole.teacher => 'Oʻqituvchi',
                              }),
                              icon: Icon(switch (role) {
                                AppRole.director =>
                                  Icons.admin_panel_settings_rounded,
                                AppRole.parent => Icons.family_restroom_rounded,
                                AppRole.teacher => Icons.school_rounded,
                              }),
                            ),
                          )
                          .toList(),
                      selected: {_role},
                      onSelectionChanged: (value) =>
                          setState(() => _role = value.first),
                    ),
                  ),
                  const SizedBox(height: 32),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _role != AppRole.parent
                        ? Column(
                            key: const ValueKey('director_fields'),
                            children: [
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: l10n.email,
                                  hintText: 'name@school.com',
                                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: l10n.password,
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            key: const ValueKey('parent_fields'),
                            children: [
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: l10n.phone,
                                  hintText: '+992 92 840 1115',
                                  prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 20),
                                ),
                              ),
                            ],
                          ),
                  ),

                  if (auth.error != null && auth.error != 'registration_required') ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.error.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              auth.error!,
                              style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  
                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: theme.elevatedButtonTheme.style,
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(l10n.signIn),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.needSupport,
                        style: theme.textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          l10n.contact,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
