import 'package:flutter/material.dart';

import '../services/app_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  /// [initialMode] is the stored choice when main() has already read it --
  /// which it does, so that the first frame is painted in the right theme
  /// instead of flashing the default one. The async fallback stays for
  /// tests and for any caller that builds the providers on their own.
  ThemeProvider({AppPreferences? preferences, ThemeMode? initialMode})
      : _preferences = preferences ?? AppPreferences(),
        _mode = initialMode ?? ThemeMode.system {
    if (initialMode == null) _restore();
  }

  final AppPreferences _preferences;

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  /// Reads the stored choice on startup. Runs unawaited from the
  /// constructor: the app opens on the system theme for the one frame this
  /// takes, which is invisible, and every alternative means holding the
  /// splash screen for a disk read.
  Future<void> _restore() async {
    final stored = await _preferences.readThemeMode();
    final mode = parse(stored);
    if (mode == null || mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    _preferences.writeThemeMode(mode.name);
  }

  static ThemeMode? parse(String? name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
}
