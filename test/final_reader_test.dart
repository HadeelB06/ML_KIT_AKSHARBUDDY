import 'dart:io';
import 'package:aksharally_ui/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aksharally_ui/screens/output_screen.dart';
import 'package:aksharally_ui/screens/ocr_review_screen.dart';
import 'package:aksharally_ui/screens/home_screen.dart';
import 'package:aksharally_ui/services/library_storage.dart';
import 'package:aksharally_ui/theme/accessibility_settings.dart';
import 'package:aksharally_ui/theme/ui_accessibility.dart';

void main() {
  final calls = <MethodCall>[];
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('aksharbuddy/voices'), (
          call,
        ) async {
          return [
            for (final locale in ['en-IN', 'hi-IN', 'mr-IN'])
              {'name': 'offline-$locale', 'locale': locale},
          ];
        });
    await LibraryStorage.load();
    await AccessibilitySettings.load();
    await UIAccessibility.load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
          call,
        ) async {
          calls.add(call);
          return 1;
        });
  });
  Future<void> render(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(600, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(theme: UIAccessibility.buildTheme(), home: child),
    );
    await t.pumpAndSettle();
  }

  testWidgets('progress replaced by settings in navigation', (t) async {
    await render(t, const HomeScreen());
    expect(find.text('Progress'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
  });
  testWidgets('reader preserves original and result in offline storage', (
    t,
  ) async {
    await render(
      t,
      const OutputScreen(
        originalText: 'The complicated passage.',
        displayText: 'The simple passage.',
        saveOnLoad: true,
      ),
    );
    expect(find.text('Start session'), findsNothing);
    await t.tap(find.text('Original'));
    await t.pumpAndSettle();
    expect(find.text('complicated'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    await LibraryStorage.load();
    expect(
      LibraryStorage.getItems().single.originalText,
      'The complicated passage.',
    );
    expect(LibraryStorage.getItems().single.content, 'The simple passage.');
  });
  testWidgets('listen pauses and resumes through device speech interface', (
    t,
  ) async {
    await render(
      t,
      const OutputScreen(displayText: 'One two three.', language: 'en'),
    );
    await t.tap(find.text('Listen'));
    await t.pumpAndSettle();
    expect(find.text('Pause'), findsOneWidget);
    await t.tap(find.text('Pause'));
    await t.pumpAndSettle();
    expect(find.text('Resume'), findsOneWidget);
    await t.tap(find.text('Resume'));
    await t.pumpAndSettle();
    expect(calls.where((c) => c.method == 'speak').length, 2);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
  testWidgets('saved reading resumes from the stored character position', (
    t,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reading_position_saved', 4);
    await render(
      t,
      const OutputScreen(displayText: 'One two three.', readingId: 'saved'),
    );
    expect(find.text('Resume'), findsOneWidget);
    await t.tap(find.text('Resume'));
    await t.pumpAndSettle();
    final spoken = calls.lastWhere((c) => c.method == 'speak');
    expect(spoken.arguments, 'two three.');
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
  testWidgets(
    'guest reading remains available when Firebase cannot initialize',
    (t) async {
      await render(t, const AppInitializer());
      await t.pump(const Duration(seconds: 11));
      await t.pumpAndSettle();
      expect(find.text('Try without an account'), findsOneWidget);
      await t.tap(find.text('Try without an account'));
      await t.pumpAndSettle();
      expect(find.text('Read at your pace'), findsOneWidget);
    },
  );
  testWidgets('unchanged model text has explicit notice', (t) async {
    await render(
      t,
      const OutputScreen(
        originalText: 'Read this.',
        displayText: 'Read this.',
        simplificationRequested: true,
      ),
    );
    expect(
      find.textContaining('did not produce a simpler version'),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
  testWidgets('OCR review requires nonempty corrected text', (t) async {
    await render(
      t,
      OcrReviewScreen(text: 'Incorrect text', source: File('sample.pdf')),
    );
    await t.enterText(find.byType(TextField), '');
    await t.tap(find.text('Save my edits'));
    await t.pumpAndSettle();
    expect(find.text('Enter some text to continue.'), findsOneWidget);
    expect(calls.where((c) => c.method == 'speak'), isEmpty);
  });
}
