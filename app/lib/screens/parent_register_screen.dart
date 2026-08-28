import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../services/parent_auth_service.dart';
import '../utils/error_formatter.dart';
import '../widgets/flag_badge.dart';
import 'parent_setup_screen.dart';

const String _tajikistanPhonePrefix = '+992';

/// Step one of signing up: which number is this?
///
/// Reached from the Register button under the sign-in form, and it asks for
/// exactly one thing. The number has to be one the school already registered
/// -- a parent identity only ever comes from a director adding their child --
/// so the useful failure here is "ask your school", not "create an account".
class ParentRegisterScreen extends StatefulWidget {
  const ParentRegisterScreen({super.key});

  @override
  State<ParentRegisterScreen> createState() => _ParentRegisterScreenState();
}

class _ParentRegisterScreenState extends State<ParentRegisterScreen> {
  final _phoneController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final digits = _phoneController.text.trim();
    if (digits.length < 9) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Asked for here rather than on the next screen so a number the school
      // does not know fails on the screen where it was typed, instead of
      // sending the parent to a code field for a code that never comes.
      await context.read<ParentAuthService>().requestCode(phone: digits);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParentSetupScreen(phone: digits, codeAlreadySent: true),
        ),
      );
    } catch (exception) {
      if (mounted) setState(() => _error = classifyError(exception));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text(l10n.registerTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: AppRadius.xlRadius,
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.registerSubtitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.colors.surfaceAlt,
                            borderRadius: AppRadius.mdRadius,
                            border: Border.all(color: context.colors.border),
                          ),
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
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _busy ? null : _continue(),
                            decoration: InputDecoration(
                              labelText: l10n.phone,
                              hintText: '92 840 1115',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        humanReadableError(_error, l10n),
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _busy || _phoneController.text.trim().length < 9
                          ? null
                          : _continue,
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.codeVerify),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
