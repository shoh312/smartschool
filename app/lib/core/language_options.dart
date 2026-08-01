import 'package:flutter/widgets.dart';

class LanguageOption {
  const LanguageOption(this.locale, this.countryCode, this.label);

  final Locale locale;

  /// 'tj', 'ru', or 'gb' -- matches FlagBadge's countryCode.
  final String countryCode;
  final String label;
}

const List<LanguageOption> kLanguageOptions = [
  LanguageOption(Locale('tg'), 'tj', 'Тоҷикӣ'),
  LanguageOption(Locale('ru'), 'ru', 'Русский'),
  LanguageOption(Locale('en'), 'gb', 'English'),
];
