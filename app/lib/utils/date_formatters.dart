import 'package:smartschool_app/generated/app_localizations.dart';

class DateFormatters {
  static String shortDate(DateTime? value) {
    if (value == null) return '-';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String time(DateTime? value) {
    if (value == null) return '-';
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  static String monthYear(AppLocalizations l10n, DateTime month) {
    final name = switch (month.month) {
      1 => l10n.month1,
      2 => l10n.month2,
      3 => l10n.month3,
      4 => l10n.month4,
      5 => l10n.month5,
      6 => l10n.month6,
      7 => l10n.month7,
      8 => l10n.month8,
      9 => l10n.month9,
      10 => l10n.month10,
      11 => l10n.month11,
      _ => l10n.month12,
    };
    return '$name ${month.year}';
  }
}
