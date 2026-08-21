import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../models/app_role.dart';
import '../providers/auth_provider.dart' as my_auth;
import '../routes/app_routes.dart';
import 'change_password_screen.dart';
import '../services/discovery_service.dart';
import '../services/token_storage.dart';
import '../utils/error_formatter.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/flag_badge.dart';
import '../widgets/language_picker_sheet.dart';
import 'registration_details_screen.dart';

const String _tajikistanPhonePrefix = '+992';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
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

    // Staff sign in against the school's own server, and the splash screen
    // only looks for it when the restored role needs it. Someone signing out
    // of a parent or pupil session lands straight here, so the address may
    // never have been resolved on this launch.
    if (roleUsesSchoolServer(_role)) {
      await resolveSchoolServerUrl(context.read<TokenStorage>());
      if (!mounted) return;
    }

    if (_role == AppRole.director) {
      final success = await auth.loginDirector(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted || !success) return;
      if (auth.mustChangePassword) {
        // Nowhere else until it's done -- see ChangePasswordScreen.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
        );
        return;
      }
      Navigator.pushReplacementNamed(context, AppRoutes.main);
    } else if (_role == AppRole.teacher) {
      final success = await auth.loginTeacher(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted || !success) return;
      Navigator.pushReplacementNamed(context, AppRoutes.main);
    } else if (_role == AppRole.student) {
      final success = await auth.loginStudent(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted || !success) return;
      Navigator.pushReplacementNamed(context, AppRoutes.main);
    } else {
      // Parent Login - Bypassing OTP
      final phoneNumber = '$_tajikistanPhonePrefix${_phoneController.text.trim()}';
      if (_phoneController.text.trim().length < 9) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invalidPhoneError)),
        );
        return;
      }

      setState(() => _isAuthenticating = true);

      try {
        final success = await auth.loginParent(phoneNumber);
        if (success && mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.main);
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
            SnackBar(content: Text(l10n.errorPrefix(humanReadableError(e, l10n)))),
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
      backgroundColor: context.colors.background,
      body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: l10n.language,
                  icon: const Icon(Icons.language_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: context.colors.surface,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
                  ),
                  onPressed: () => showLanguagePickerSheet(context),
                ),
              ),
              Center(
            child: SingleChildScrollView(
              padding: (const EdgeInsets.symmetric(horizontal: 28, vertical: 24)).add(bottomNavPadding(context)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.colored(context.colors.primary),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l10n.title,
                    style: theme.textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.login_desc,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: AppRadius.xlRadius,
                      border: Border.all(color: context.colors.border),
                      boxShadow: AppShadows.raised,
                    ),
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  _RoleSelector(
                    selected: _role,
                    onChanged: (role) => setState(() => _role = role),
                  ),
                  const SizedBox(height: 28),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _role == AppRole.director || _role == AppRole.teacher
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
                        : _role == AppRole.student
                        ? Column(
                            key: const ValueKey('student_fields'),
                            children: [
                              TextField(
                                controller: _emailController,
                                autofocus: true,
                                decoration: InputDecoration(
                                  labelText: l10n.studentUsernameLabel,
                                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 56,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: context.colors.surfaceAlt,
                                      borderRadius: AppRadius.mdRadius,
                                      border: Border.all(color: context.colors.border),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const FlagBadge(countryCode: 'tj', width: 26, height: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          _tajikistanPhonePrefix,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: context.colors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneController,
                                      autofocus: true,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(9),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: l10n.phone,
                                        hintText: '92 840 1115',
                                      ),
                                    ),
                                  ),
                                ],
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
                              humanReadableError(auth.error, l10n),
                              style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

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
                  ],
                    ),
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
            ],
          ),
        ),
    );
  }
}

/// The four sign-in roles as a 2x2 grid of cards.
///
/// Was a `SegmentedButton` across the full width: four segments sharing one
/// row left each role barely 60px, so every Tajik label wrapped mid-word
/// ("Дирек тор", "Волид айн") and the control became unreadable. A grid
/// gives each role a full line of text plus room for its icon.
class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.selected, required this.onChanged});

  final AppRole selected;
  final ValueChanged<AppRole> onChanged;

  static IconData _iconFor(AppRole role) => switch (role) {
        AppRole.director => Icons.admin_panel_settings_rounded,
        AppRole.parent => Icons.family_restroom_rounded,
        AppRole.teacher => Icons.school_rounded,
        AppRole.student => Icons.backpack_rounded,
      };

  static String _labelFor(AppLocalizations l10n, AppRole role) => switch (role) {
        AppRole.director => l10n.roleDirector,
        AppRole.parent => l10n.roleParent,
        AppRole.teacher => l10n.roleTeacher,
        AppRole.student => l10n.roleStudent,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final tileWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final role in AppRole.values)
              SizedBox(
                width: tileWidth,
                child: _RoleTile(
                  icon: _iconFor(role),
                  label: _labelFor(l10n, role),
                  isSelected: role == selected,
                  onTap: () => onChanged(role),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    return Material(
      color: isSelected ? accent.withOpacity(0.12) : context.colors.surfaceAlt,
      borderRadius: AppRadius.mdRadius,
      child: InkWell(
        borderRadius: AppRadius.mdRadius,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdRadius,
            border: Border.all(
              color: isSelected ? accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: isSelected ? accent : context.colors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? accent : context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
