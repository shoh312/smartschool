import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

import 'core/app.dart';
import 'providers/app_providers.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'services/app_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Read before the first frame: theme and language decide what every
  // screen looks like, and applying them a frame later would repaint the
  // whole app in front of the user.
  final preferences = AppPreferences();
  final themeMode = ThemeProvider.parse(await preferences.readThemeMode());
  final locale = LanguageProvider.parse(await preferences.readLanguageCode());

  runApp(
    MultiProvider(
      providers: buildAppProviders(
        initialThemeMode: themeMode,
        initialLocale: locale,
      ),
      child: const SmartSchoolRoot(),
    ),
  );
}

class SmartSchoolRoot extends StatelessWidget {
  const SmartSchoolRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const SmartSchoolApp();
  }
}
