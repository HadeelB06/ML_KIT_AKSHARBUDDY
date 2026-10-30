import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_localizations.dart';
import 'widgets/assistant_widgets.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_settings.dart';
import 'theme/accessibility_settings.dart';
import 'theme/ui_accessibility.dart';
import 'services/library_storage.dart';
import 'services/buddy_store.dart';
import 'widgets/buddy_brand.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.load();
  await AppLocalizations.load();
  // Restore reader accessibility preferences before the first frame.
  await AccessibilitySettings.load();
  // Restore UI accessibility preferences (font, spacing, color theme).
  await UIAccessibility.load();
  // Hydrate reading history from SharedPreferences before the first frame.
  await LibraryStorage.load();
  await BuddyStore.load();
  runApp(const AppInitializer());
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late final Future<FirebaseApp> _firebaseInit;

  @override
  void initState() {
    super.initState();
    _firebaseInit = Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _firebaseInit,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: Scaffold(
              backgroundColor: Color(0xFFF4F7F1),
              body: Center(child: BuddyMark(size: 112)),
            ),
          );
        }

        // Guest reading must remain available when authentication cannot start.
        return const AksharBuddyApp();
      },
    );
  }
}

/// Root app widget.  Wrapped in ValueListenableBuilder so that every time
/// UIAccessibility.notifier fires the MaterialApp rebuilds with the new
/// ThemeData — instant global font/colour propagation, no Provider needed.
class AksharBuddyApp extends StatelessWidget {
  const AksharBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppLocalizations.notifier,
      builder: (_, revision, child) => ValueListenableBuilder<int>(
        valueListenable: UIAccessibility.notifier,
        builder: (_, _, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(AppLocalizations.language),
          supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          navigatorObservers: [AssistantRouteObserver()],
          theme: UIAccessibility.buildTheme(),
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
          },
        ),
      ),
    );
  }
}
