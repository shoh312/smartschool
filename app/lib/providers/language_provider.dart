import 'package:flutter/material.dart';

import '../services/app_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  /// See ThemeProvider's constructor: the locale changes MaterialApp's key,
  /// so restoring it a frame late would remount the whole app -- and with
  /// it the splash screen, which would then run its session restore and
  /// server discovery twice.
  LanguageProvider({AppPreferences? preferences, Locale? initialLocale})
      : _preferences = preferences ?? AppPreferences(),
        _locale = initialLocale ?? const Locale('tg') {
    if (initialLocale == null) _restore();
  }

  static const supported = ['tg', 'ru', 'en'];

  final AppPreferences _preferences;

  Locale _locale;

  Locale get locale => _locale;

  Future<void> _restore() async {
    final locale = parse(await _preferences.readLanguageCode());
    if (locale == null || locale.languageCode == _locale.languageCode) return;
    _locale = locale;
    notifyListeners();
  }

  static Locale? parse(String? code) =>
      code != null && supported.contains(code) ? Locale(code) : null;

  void setLocale(Locale locale) {
    if (!supported.contains(locale.languageCode)) return;
    if (locale.languageCode == _locale.languageCode) return;
    _locale = locale;
    notifyListeners();
    _preferences.writeLanguageCode(locale.languageCode);
  }
}
