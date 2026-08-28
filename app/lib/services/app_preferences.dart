import 'package:shared_preferences/shared_preferences.dart';

/// The two choices that belong to the phone rather than to the session.
///
/// Theme and language were held in memory only, so every choice lasted until
/// the app was closed and then snapped back to Tajik and system theme. They
/// are deliberately not in TokenStorage: that is cleared on sign-out, and a
/// parent who picked Russian should still find Russian after signing out.
class AppPreferences {
  static const _themeKey = 'theme_mode';
  static const _languageKey = 'language_code';

  Future<String?> readThemeMode() async =>
      (await SharedPreferences.getInstance()).getString(_themeKey);

  Future<void> writeThemeMode(String mode) async =>
      (await SharedPreferences.getInstance()).setString(_themeKey, mode);

  Future<String?> readLanguageCode() async =>
      (await SharedPreferences.getInstance()).getString(_languageKey);

  Future<void> writeLanguageCode(String code) async =>
      (await SharedPreferences.getInstance()).setString(_languageKey, code);
}
