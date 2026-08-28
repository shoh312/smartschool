import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../providers/auth_provider.dart' as my_auth;
import '../providers/nav_provider.dart';
import '../routes/app_routes.dart';
import '../services/discovery_service.dart';
import '../services/token_storage.dart';
import '../utils/error_formatter.dart';
import '../widgets/bottom_nav_inset.dart';
import '../widgets/language_picker_sheet.dart';
import 'change_password_screen.dart';
import 'parent_register_screen.dart';
import 'parent_setup_screen.dart';

/// What the person typed into the single identifier field.
///
/// Public so it can be tested on its own: it decides which *server* the
/// credentials are sent to, so it is the one piece of this screen that must
/// not be verified by hand.
///
/// The screen used to ask them to pick their role from four cards first,
/// which is a question the app can answer itself: nobody's phone number
/// contains an `@`, and no email is nine digits. Getting it wrong is not
/// silent either -- the wrong guess simply fails to authenticate, exactly as
/// a wrong password would.
enum IdentifierKind { phone, email, username }

IdentifierKind classifyIdentifier(String raw) {
  final value = raw.trim();
  if (value.contains('@')) return IdentifierKind.email;

  final digits = value.replaceAll(RegExp(r'[\s\-()+]'), '');
  if (digits.isNotEmpty && int.tryParse(digits) != null) return IdentifierKind.phone;

  return IdentifierKind.username;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Only to swap the keyboard between digits and letters as they type.
    _identifierController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<my_auth.AuthProvider>();
    final storage = context.read<TokenStorage>();
    // A new session starts on the dashboard, never on the tab the previous
    // one was left on.
    context.read<NavProvider>().reset();

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    if (identifier.isEmpty) return;

    switch (classifyIdentifier(identifier)) {
      case IdentifierKind.email:
        // Staff sign in against the school's own server, and the splash
        // screen only looks for it when the restored role needs it. Someone
        // signing out of a parent session lands straight here, so the
        // address may never have been resolved on this launch.
        await resolveSchoolServerUrl(storage);
        if (!mounted) return;
        if (!await auth.loginStaff(identifier, password)) return;
        if (!mounted) return;
        if (auth.mustChangePassword) {
          // Nowhere else until it's done -- see ChangePasswordScreen.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
          );
          return;
        }
        Navigator.pushReplacementNamed(context, AppRoutes.main);

      case IdentifierKind.username:
        if (!await auth.loginStudent(identifier, password)) return;
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.main);

      case IdentifierKind.phone:
        final signedIn = await auth.loginParent(identifier, password);
        if (!mounted) return;
        if (signedIn) {
          Navigator.pushReplacementNamed(context, AppRoutes.main);
          return;
        }
        // Registered before passwords existed, or never finished signing
        // up: both end at the same code screen.
        if (auth.parentNeedsPassword) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ParentSetupScreen(phone: identifier),
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<my_auth.AuthProvider>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final kind = classifyIdentifier(_identifierController.text);

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
                padding: (const EdgeInsets.symmetric(horizontal: 28, vertical: 24))
                    .add(bottomNavPadding(context)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      Center(
                        child: Image.asset(
                          'assets/brand/logo.png',
                          width: 104,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 24),
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
                            TextField(
                              // Rebuilt when the kind changes so the number
                              // pad appears for a phone and letters for an
                              // address, without asking which it is.
                              key: ValueKey(kind),
                              controller: _identifierController,
                              autofocus: true,
                              keyboardType: switch (kind) {
                                IdentifierKind.phone => TextInputType.phone,
                                IdentifierKind.email => TextInputType.emailAddress,
                                IdentifierKind.username => TextInputType.text,
                              },
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l10n.identifierLabel,
                                hintText: l10n.identifierHint,
                                prefixIcon: Icon(
                                  switch (kind) {
                                    IdentifierKind.phone => Icons.phone_outlined,
                                    IdentifierKind.email => Icons.email_outlined,
                                    IdentifierKind.username => Icons.person_outline_rounded,
                                  },
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => auth.isLoading ? null : _submit(),
                              decoration: InputDecoration(
                                labelText: l10n.password,
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            if (auth.error != null) ...[
                              const SizedBox(height: 20),
                              _ErrorBox(message: humanReadableError(auth.error, l10n)),
                            ],
                            const SizedBox(height: 28),
                            ElevatedButton(
                              onPressed: auth.isLoading ? null : _submit,
                              style: theme.elevatedButtonTheme.style,
                              child: auth.isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(l10n.signIn),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Parents are the only role that signs itself up --
                      // staff and pupils are given their logins by the
                      // school -- so this is the one door that has to be
                      // visible on the sign-in screen rather than reached
                      // by failing to sign in first.
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ParentRegisterScreen(),
                          ),
                        ),
                        child: Text(
                          l10n.registerAction,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l10n.needSupport, style: theme.textTheme.bodyMedium),
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
              message,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
