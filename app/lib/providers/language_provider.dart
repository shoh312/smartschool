import 'package:flutter/material.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('tg');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (!['tg', 'ru', 'en'].contains(locale.languageCode)) return;
    _locale = locale;
    notifyListeners();
  }
}
