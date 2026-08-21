import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

/// The screen a director cannot get past while their account still carries
/// the password shipped in the source code.
///
/// Deliberately a dead end: no back button, no skip. A school running on a
/// password anyone can read in the repository does not have an account
/// system, and the only useful moment to insist is the one where they have
/// just proved they know the current password.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = true});

  /// False when opened voluntarily from settings -- then it can be left.
  final bool forced;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;

    // Checked here as well as on the server: the server is the authority,
    // but a round trip to be told "too short" is a poor way to find out.
    if (_next.text.length < 8) {
      setState(() => _error = l10n.passwordTooShort);
      return;
    }
    if (_next.text != _repeat.text) {
      setState(() => _error = l10n.passwordMismatch);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    try {
      await auth.changeDirectorPassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
      if (widget.forced) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (_) => false);
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      setState(() {
        _error = message.contains('password_is_default')
            ? l10n.passwordIsDefault
            : message.contains('password_too_short')
                ? l10n.passwordTooShort
                : message;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return PopScope(
      // A forced change can't be dismissed with the back gesture either.
      canPop: !widget.forced,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(l10n.passwordChangeTitle),
          automaticallyImplyLeading: !widget.forced,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              if (widget.forced)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.10),
                    borderRadius: AppRadius.mdRadius,
                    border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 20, color: colors.warning),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.passwordChangeWhy,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              _Field(controller: _current, label: l10n.passwordCurrent),
              const SizedBox(height: 12),
              _Field(controller: _next, label: l10n.passwordNew),
              const SizedBox(height: 12),
              _Field(controller: _repeat, label: l10n.passwordRepeat),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 13, color: colors.danger),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.passwordSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: context.colors.surface,
        border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
      ),
    );
  }
}
