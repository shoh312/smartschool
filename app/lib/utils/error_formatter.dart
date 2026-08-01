import 'package:smartschool_app/generated/app_localizations.dart';

import '../services/api_client.dart';

/// Reduces any caught exception down to a small, language-neutral string
/// that a [ChangeNotifier] provider can safely store in a `String? error`
/// field (providers have no [AppLocalizations]/BuildContext to localize
/// with). Call [humanReadableError] at display time, once an
/// [AppLocalizations] is available, to turn this back into text the user
/// can actually read.
String classifyError(Object exception) {
  if (exception is NetworkException) return 'network';
  if (exception is ApiException) {
    final message = exception.message.trim();
    return message.isEmpty ? 'server' : 'server:$message';
  }
  return 'unknown';
}

/// Stable, language-neutral codes the backend returns in `detail` for
/// errors a user might actually see (as opposed to English admin/dev-facing
/// messages like "Class not found") -- kept in sync with the `detail=`
/// strings in `auth_service.py`, `teacher_service.py`, and the Public
/// Server's `auth_router.py`. Mapped to localized text below so the same
/// login failure reads correctly in all 3 app languages.
const _knownBackendCodes = {
  'phone_not_registered',
  'invalid_credentials',
  'account_inactive',
  'invalid_current_password',
};

/// Turns a code produced by [classifyError] (or a raw exception passed
/// directly) into a human-readable, localized message. Never surfaces raw
/// OS/socket/stack-trace text to the user.
String humanReadableError(Object? errorOrCode, AppLocalizations l10n) {
  if (errorOrCode == null) return '';
  final code = errorOrCode is String ? errorOrCode : classifyError(errorOrCode);
  if (code.isEmpty) return '';
  if (code == 'network') return l10n.networkErrorMessage;
  if (code == 'server') return l10n.serverErrorMessage;
  if (code.startsWith('server:')) {
    final backendCode = code.substring('server:'.length);
    if (!_knownBackendCodes.contains(backendCode)) {
      // Not one of the codes above -- an existing English admin/dev-facing
      // detail string (e.g. "Class not found"). Shown as-is: still clearer
      // than a generic fallback, and not yet worth a full localization pass.
      return backendCode;
    }
    switch (backendCode) {
      case 'phone_not_registered':
        return l10n.phoneNotRegisteredMessage;
      case 'invalid_credentials':
        return l10n.invalidCredentialsMessage;
      case 'account_inactive':
        return l10n.accountInactiveMessage;
      case 'invalid_current_password':
        return l10n.invalidCurrentPasswordMessage;
    }
  }
  return l10n.unknownErrorMessage;
}
