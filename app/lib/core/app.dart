import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../routes/app_routes.dart';
import '../screens/splash_screen.dart';
import '../providers/language_provider.dart';
import 'theme.dart';

class SmartSchoolApp extends StatelessWidget {
  const SmartSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    
    return MaterialApp(
      key: ValueKey(langProvider.locale.languageCode),
      title: 'SmartSchool',
      debugShowCheckedModeBanner: false,
      theme: SmartSchoolTheme.light(),
      locale: langProvider.locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        _TajikMaterialLocalizationsDelegate(),
        _TajikCupertinoLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routes: AppRoutes.routes,
      home: const SplashScreen(),
    );
  }
}

class _TajikMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tg';
  @override
  Future<MaterialLocalizations> load(Locale locale) => GlobalMaterialLocalizations.delegate.load(const Locale('ru'));
  @override
  bool shouldReload(_TajikMaterialLocalizationsDelegate old) => false;
}

class _TajikCupertinoLocalizationsDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tg';
  @override
  Future<CupertinoLocalizations> load(Locale locale) => GlobalCupertinoLocalizations.delegate.load(const Locale('ru'));
  @override
  bool shouldReload(_TajikCupertinoLocalizationsDelegate old) => false;
}
