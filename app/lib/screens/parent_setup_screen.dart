import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../providers/auth_provider.dart' as my_auth;
import '../routes/app_routes.dart';
import '../services/parent_auth_service.dart';
import '../utils/error_formatter.dart';

/// Proves the phone is theirs, then lets them choose a password.
///
/// Two steps on one screen rather than two screens: the second half is
/// revealed once the code is accepted, so the parent never loses sight of
/// which number they are setting up, and going back does not mean starting
/// over.
class ParentSetupScreen extends StatefulWidget {
  const ParentSetupScreen({
    super.key,
    required this.phone,
    this.codeAlreadySent = false,
  });

  final String phone;

  /// Set when the previous screen already asked for the code, so this one
  /// does not immediately ask for a second and burn one of the three a
  /// number is allowed per hour.
  final bool codeAlreadySent;

  @override
  State<ParentSetupScreen> createState() => _ParentSetupScreenState();
}

class _ParentSetupScreenState extends State<ParentSetupScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repeatController = TextEditingController();

  String _maskedPhone = '';
  bool _delivered = false;
  bool _busy = false;
  String? _error;
  String? _setupToken;

  @override
  void initState() {
    super.initState();
    if (widget.codeAlreadySent) {
      _delivered = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestCode());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  ParentAuthService get _service => context.read<ParentAuthService>();

  Future<void> _requestCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _service.requestCode(phone: widget.phone);
      if (!mounted) return;
      setState(() {
        _maskedPhone = result.maskedPhone;
        _delivered = result.delivered;
      });
    } catch (exception) {
      if (mounted) setState(() => _error = classifyError(exception));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _service.verifyCode(phone: widget.phone, code: code);
      if (!mounted) return;
      setState(() {
        _setupToken = result.setupToken;
        // The school already typed a name when the child was registered;
        // offering it saves the parent from typing their own name again,
        // and they can correct it if it is wrong.
        _nameController.text = result.fullName ?? '';
      });
    } catch (exception) {
      if (mounted) setState(() => _error = classifyError(exception));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final password = _passwordController.text;

    if (password.length < 4) {
      setState(() => _error = l10n.passwordTooShort);
      return;
    }
    if (password != _repeatController.text) {
      setState(() => _error = l10n.passwordMismatch);
      return;
    }

    setState(() => _error = null);
    final auth = context.read<my_auth.AuthProvider>();
    final done = await auth.completeParentSetup(
      setupToken: _setupToken!,
      fullName: _nameController.text.trim(),
      password: password,
    );
    if (!mounted) return;
    if (done) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (_) => false);
    } else {
      setState(() => _error = auth.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final verified = _setupToken != null;
    final busy = _busy || context.watch<my_auth.AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text(verified ? l10n.setupTitle : l10n.codeTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: AppRadius.xlRadius,
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!verified) ..._codeStep(l10n, theme, busy),
                        if (verified) ..._passwordStep(l10n, busy),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _codeStep(AppLocalizations l10n, ThemeData theme, bool busy) => [
        Text(
          l10n.codeSentTo(_maskedPhone),
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        // Said plainly rather than left to a parent staring at a phone that
        // will never buzz: until the school has a gateway contract the code
        // only exists in the server log.
        if (!_delivered) ...[
          const SizedBox(height: 8),
          Text(
            l10n.codeNotDelivered,
            style: TextStyle(fontSize: 13, color: context.colors.warning),
          ),
        ],
        const SizedBox(height: 22),
        TextField(
          controller: _codeController,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(labelText: l10n.codeLabel, hintText: '••••••'),
          onSubmitted: (_) => busy ? null : _verify(),
        ),
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: busy ? null : _verify,
          child: busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text(l10n.codeVerify),
        ),
        TextButton(
          onPressed: busy ? null : _requestCode,
          child: Text(l10n.codeResend),
        ),
      ];

  List<Widget> _passwordStep(AppLocalizations l10n, bool busy) => [
        Text(
          l10n.setupSubtitle,
          style: TextStyle(fontSize: 13.5, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.fullName,
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.passwordNew,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _repeatController,
          obscureText: true,
          onSubmitted: (_) => busy ? null : _save(),
          decoration: InputDecoration(
            labelText: l10n.passwordRepeat,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: busy ? null : _save,
          child: busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text(l10n.setupSave),
        ),
      ];
}
