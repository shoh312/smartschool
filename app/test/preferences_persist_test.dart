// Theme and language survive closing the app.
//
// They did not: both providers held their value in memory only, so every
// choice lasted until the process died and then snapped back to Tajik and
// the system theme. The bug is invisible in a hot reload -- the process
// never dies -- which is why it lived so long.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartschool_app/providers/language_provider.dart';
import 'package:smartschool_app/providers/theme_provider.dart';
import 'package:smartschool_app/services/app_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a chosen theme is still there next launch', () async {
    ThemeProvider().setMode(ThemeMode.dark);
    // The write is fire-and-forget, as it is in the UI.
    await Future<void>.delayed(Duration.zero);

    // What main() does on the next launch.
    final stored = await AppPreferences().readThemeMode();
    expect(ThemeProvider.parse(stored), ThemeMode.dark);
    expect(ThemeProvider(initialMode: ThemeProvider.parse(stored)).mode, ThemeMode.dark);
  });

  test('a chosen language is still there next launch', () async {
    LanguageProvider().setLocale(const Locale('ru'));
    await Future<void>.delayed(Duration.zero);

    final stored = await AppPreferences().readLanguageCode();
    expect(LanguageProvider.parse(stored)?.languageCode, 'ru');
  });

  test('nothing stored means the defaults', () async {
    expect(ThemeProvider.parse(null), isNull);
    expect(LanguageProvider.parse(null), isNull);
    expect(ThemeProvider().mode, ThemeMode.system);
    expect(LanguageProvider().locale.languageCode, 'tg');
  });

  test('a language the app no longer ships is ignored', () async {
    // Rather than starting up in a locale with no translations at all.
    expect(LanguageProvider.parse('fr'), isNull);
  });

  test('the async fallback restores when main did not preload', () async {
    await AppPreferences().writeThemeMode('light');

    final provider = ThemeProvider();
    expect(provider.mode, ThemeMode.system, reason: 'before the read lands');

    await Future<void>.delayed(Duration.zero);
    expect(provider.mode, ThemeMode.light);
  });
}
