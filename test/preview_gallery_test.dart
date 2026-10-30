import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aksharally_ui/theme/app_localizations.dart';
import 'package:aksharally_ui/theme/ui_accessibility.dart';
import 'package:aksharally_ui/theme/accessibility_settings.dart';
import 'package:aksharally_ui/screens/splash_screen.dart';
import 'package:aksharally_ui/screens/style_preview_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Marathi welcome and preview fit a phone', (tester) async {
    SharedPreferences.setMockInitialValues({'assistant_ui_language': 'mr'});
    await AppLocalizations.load();
    await UIAccessibility.load();
    await AccessibilitySettings.load();
    for (final entry in {
      'BuddySans': 'assets/fonts/BuddySans/roboto-regular.ttf',
      'NotoSansDevanagari': 'assets/fonts/NotoSansDevanagari/NotoSansDevanagari.ttf',
      'OpenDyslexic': 'assets/fonts/OpenDyslexic/OpenDyslexic3-Regular.ttf',
      'Lexend': 'assets/fonts/Lexend/Lexend.ttf',
      'AtkinsonHyperlegible': 'assets/fonts/AtkinsonHyperlegible/AtkinsonHyperlegible.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value))).load();
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final entry in <String, Widget>{
      '14-marathi-welcome': const SplashScreen(),
      '15-marathi-preview': const StylePreviewScreen(),
    }.entries) {
      await tester.pumpWidget(RepaintBoundary(key: const Key('gallery'), child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('mr'), supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: UIAccessibility.buildTheme(), home: entry.value,
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('gallery')), matchesGoldenFile('goldens/${entry.key}.png'));
    }
    await tester.pumpWidget(const SizedBox());
  });
}
