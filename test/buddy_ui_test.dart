import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aksharally_ui/screens/home_screen.dart';
import 'package:aksharally_ui/screens/splash_screen.dart';
import 'package:aksharally_ui/screens/login_screen.dart';
import 'package:aksharally_ui/screens/reading_screen.dart';
import 'package:aksharally_ui/screens/output_screen.dart';
import 'package:aksharally_ui/screens/settings_screen.dart';
import 'package:aksharally_ui/screens/library_screen.dart';
import 'package:aksharally_ui/screens/words_screen.dart';
import 'package:aksharally_ui/screens/ocr_review_screen.dart';
import 'package:aksharally_ui/theme/ui_accessibility.dart';
import 'package:aksharally_ui/theme/accessibility_settings.dart';
import 'package:aksharally_ui/services/library_storage.dart';
import 'package:aksharally_ui/services/buddy_store.dart';
import 'package:aksharally_ui/models/library_item.dart';
import 'package:aksharally_ui/widgets/word_help_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UIAccessibility.load();
    await AccessibilitySettings.load();
    await LibraryStorage.load();
    await BuddyStore.load();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/image_picker'),
      (_) async => null,
    );
  });
  Future<void> render(
    WidgetTester tester,
    Widget screen, {
    double scale = 1,
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(420, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (dark) {
      UIAccessibility.backgroundColor = const Color(0xFF121212);
      UIAccessibility.textColor = const Color(0xFFF5F5F5);
    }
    final font = FontLoader('BuddySans')
      ..addFont(rootBundle.load('assets/fonts/BuddySans/roboto-regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/BuddySans/roboto-bold.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: UIAccessibility.buildTheme(),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester t, String name) => expectLater(
    find.byKey(const Key('capture')),
    matchesGoldenFile(
      Uri.file('${Directory.current.path}/test/goldens/$name.png'),
    ),
  );
  Widget page(Widget child) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    ),
  );
  testWidgets('brand and new home render in light and dark', (t) async {
    await render(t, const SplashScreen());
    await capture(t, '01-welcome');
    await render(t, const HomeScreen());
    expect(find.text('Type or paste text'), findsOneWidget);
    await capture(t, '02-home');
    await render(t, const HomeScreen(), dark: true);
    await capture(t, '03-home-dark');
  });
  testWidgets('home remains usable at 200 percent text', (t) async {
    await render(t, const HomeScreen(), scale: 2);
    await capture(t, '04-home-large-text');
  });
  testWidgets('sign in uses labelled fields at large text', (t) async {
    await render(t, const LoginScreen(), scale: 1.5);
    expect(find.text('Email address'), findsOneWidget);
    await capture(t, '05-login');
  });
  testWidgets('typed input and language choices render at large text', (
    t,
  ) async {
    await render(
      t,
      const ReadingScreen(initialTab: ReadingTab.type),
      scale: 1.5,
    );
    await capture(t, '06-input');
  });
  testWidgets('reader opens word help without automatically making a request', (
    t,
  ) async {
    await render(
      t,
      const OutputScreen(
        displayText: 'Read at your own pace.\nTake a break when you need one.',
        language: 'en',
      ),
    );
    await capture(t, '07-reader');
    await t.ensureVisible(find.text('Read'));
    await t.tap(find.text('Read'));
    await t.pumpAndSettle();
    expect(find.text('Save my note'), findsOneWidget);
    await capture(t, '08-word-help');
    await t.pumpWidget(const SizedBox());
    await t.pump();
  });
  testWidgets('library searches content and retains unfiltered data', (
    t,
  ) async {
    LibraryStorage.addItem(
      LibraryItem(
        title: 'Morning reading',
        content: 'A quiet start with sunlight.',
        date: DateTime(2026, 9, 19),
        language: 'en',
      ),
    );
    LibraryStorage.addItem(
      LibraryItem(
        title: 'Evening',
        content: 'The moon is bright.',
        date: DateTime(2026, 9, 19),
        language: 'en',
      ),
    );
    await render(t, page(const LibraryScreen()));
    await t.enterText(find.byType(TextField), 'sunlight');
    await t.pump();
    expect(find.text('Morning reading'), findsOneWidget);
    expect(find.text('Evening'), findsNothing);
    expect(LibraryStorage.getItems().length, 2);
    await capture(t, '09-library');
  });
  testWidgets('settings exposes language and assistant controls for the offline app', (t) async {
    await render(t, const Scaffold(body: SafeArea(child: SettingsScreen())));
    expect(find.text('Interface language'), findsOneWidget);
    expect(find.text('Assistant voice'), findsOneWidget);
    expect(find.text('Style preview'), findsOneWidget);
    expect(find.text('Marathi'), findsOneWidget);
    await capture(t, '10-settings');
  });
  testWidgets('saved words can be marked known and filtered', (t) async {
    await t.runAsync(
      () => BuddyStore.saveWord(
        const SavedWord(
          word: 'explore',
          language: 'en',
          definition: 'Look around to learn about a place.',
          example: 'We explore the garden.',
          source: 'Demo fixture',
        ),
      ),
    );
    await render(t, page(const WordsScreen()));
    await capture(t, '11-words');
    await t.ensureVisible(find.text('Mark Known'));
    await t.tap(find.text('Mark Known'));
    await t.pumpAndSettle();
    expect(BuddyStore.words.single.known, true);
    await t.ensureVisible(find.text('Learning'));
    await t.tap(find.text('Learning'));
    await t.pumpAndSettle();
    expect(find.text('explore'), findsNothing);
  });
  testWidgets('OCR correction is readable', (t) async {
    await render(
      t,
      OcrReviewScreen(
        text: 'Read and correct this text before continuing.',
        source: File('sample.pdf'),
      ),
    );
    await capture(t, '12-ocr-review');
  });
  testWidgets('saved dictionary meaning opens offline', (t) async {
    await t.runAsync(
      () => BuddyStore.saveWord(
        const SavedWord(
          word: 'book',
          language: 'en',
          definition: 'Pages joined together to read.',
          example: 'I open my book.',
        ),
      ),
    );
    await render(t, page(const WordHelpSheet(word: 'book', language: 'en')));
    expect(find.text('Pages joined together to read.'), findsOneWidget);
    expect(find.text('Save my note'), findsNothing);
  });
  testWidgets('words and settings tolerate 200 percent text', (t) async {
    for (final widget in [
      page(const WordsScreen()),
      const Scaffold(body: SafeArea(child: SettingsScreen())),
    ]) {
      await render(t, widget, scale: 2);
      expect(t.takeException(), isNull);
    }
  });
  testWidgets('reading appearance opens with an offline font and large text', (
    t,
  ) async {
    await render(
      t,
      const OutputScreen(displayText: 'A comfortable reading.', language: 'en'),
      scale: 1.5,
    );
    await t.tap(find.text('Reading appearance'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Customize'));
    await t.tap(find.text('Customize'));
    await t.pumpAndSettle();
    expect(find.text('Reading font'), findsOneWidget);
    expect(t.takeException(), isNull);
    await capture(t, '13-reading-appearance');
    await t.pumpWidget(const SizedBox());
    await t.pump();
  });
}
