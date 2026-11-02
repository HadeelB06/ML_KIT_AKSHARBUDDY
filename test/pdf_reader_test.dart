import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aksharally_ui/models/ocr_document.dart';
import 'package:aksharally_ui/screens/output_screen.dart';
import 'package:aksharally_ui/theme/app_localizations.dart';
import 'package:aksharally_ui/theme/ui_accessibility.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late String record;
  final calls = <MethodCall>[];
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocalizations.load();
    await UIAccessibility.load();
    calls.clear();
    temp = Directory.systemTemp.createTempSync('buddy_pages_');
    record = '${temp.path}/record.json';
    final doc = OcrDocument(
      id: 'sample',
      language: 'en',
      sourceType: 'pdf',
      totalPages: 4,
      pages: const [
        OcrPage(
          rawOcrText: 'First page only.',
          language: 'en',
          sourceType: 'pdf-native',
          pageNumber: 1,
        ),
        OcrPage(
          rawOcrText: 'Second page only.',
          userEditedText: 'Second page edited.',
          language: 'en',
          sourceType: 'pdf-mlkit',
          pageNumber: 2,
        ),
        OcrPage(
          rawOcrText: '',
          language: 'en',
          sourceType: 'pdf-mlkit',
          pageNumber: 3,
          status: 'failed',
          error: 'Unreadable scan',
        ),
      ],
    );
    File(record).writeAsStringSync(jsonEncode(doc.toJson()));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
          call,
        ) async {
          calls.add(call);
          return 1;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('aksharbuddy/voices'),
          (_) async => [
            {'name': 'offline-en', 'locale': 'en-IN'},
          ],
        );
  });
  tearDown(() => temp.deleteSync(recursive: true));
  Future<void> render(WidgetTester t, {bool phone = false}) async {
    t.view.physicalSize = phone ? const Size(390, 844) : const Size(800, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.runAsync(() async {
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: UIAccessibility.buildTheme(),
          home: OutputScreen(
            readingId: 'reader',
            displayText: 'Fallback merged text',
            extractionRecordPath: record,
            language: 'en',
          ),
        ),
      );
      // Real file I/O must start in the real async zone, outside the widget fake clock.
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await t.pump();
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
      }
    });
    await t.pumpAndSettle();
  }

  Future<void> native(String method, [Object? args]) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'flutter_tts',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, args),
          ),
          (_) {},
        );
  }

  testWidgets(
    'original and edited page text stay separate and selection persists',
    (t) async {
      await render(t);
      await t.tap(find.byTooltip('Next page'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Original'));
      await t.tap(find.text('Original'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Listen'));
      await t.tap(find.text('Listen'));
      await t.pumpAndSettle();
      expect(
        calls.lastWhere((c) => c.method == 'speak').arguments,
        'Second page only.',
      );
      await t.ensureVisible(find.byTooltip('Previous page'));
      await t.tap(find.byTooltip('Previous page'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Next page'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<ChoiceChip>(
              find.ancestor(
                of: find.text('Original'),
                matching: find.byType(ChoiceChip),
              ),
            )
            .selected,
        isTrue,
      );
      await t.ensureVisible(find.text('Your edits'));
      await t.tap(find.text('Your edits'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Listen'));
      await t.tap(find.text('Listen'));
      await t.pumpAndSettle();
      expect(
        calls.lastWhere((c) => c.method == 'speak').arguments,
        'Second page edited.',
      );
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );

  testWidgets('empty edited version still allows return to original text', (
    t,
  ) async {
    final doc = OcrDocument.fromJson(
      jsonDecode(File(record).readAsStringSync()),
    );
    File(record).writeAsStringSync(
      jsonEncode(
        doc.withPages([
          doc.pages.first.edited(''),
          ...doc.pages.skip(1),
        ]).toJson(),
      ),
    );
    await render(t);
    expect(find.text('Listen'), findsNothing);
    await t.tap(find.text('Original'));
    await t.pumpAndSettle();
    await t.tap(find.text('Listen'));
    await t.pumpAndSettle();
    expect(
      calls.lastWhere((c) => c.method == 'speak').arguments,
      'First page only.',
    );
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });

  for (final kind in ['missing', 'corrupt']) {
    testWidgets('$kind page records show warning and preserve saved text', (
      t,
    ) async {
      if (kind == 'missing') {
        File(record).deleteSync();
      } else {
        File(record).writeAsStringSync('{invalid');
      }
      await render(t);
      expect(
        find.textContaining('page boundaries cannot be verified'),
        findsOneWidget,
      );
      expect(find.byTooltip('Next page'), findsNothing);
      await t.tap(find.text('Listen'));
      await t.pumpAndSettle();
      expect(
        calls.lastWhere((c) => c.method == 'speak').arguments,
        'Fallback merged text',
      );
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  }

  testWidgets(
    'navigation stops speech, saves offset and restores it after reopening',
    (t) async {
      await render(t);
      await t.tap(find.text('Listen'));
      await t.pumpAndSettle();
      await native('speak.onProgress', {
        'text': 'First page only.',
        'start': '6',
        'end': '10',
        'word': 'page',
      });
      await t.pump();
      calls.clear();
      await t.tap(find.byTooltip('Next page'));
      await t.pumpAndSettle();
      expect(calls.any((c) => c.method == 'stop'), isTrue);
      expect(calls.any((c) => c.method == 'speak'), isFalse);
      expect(
        (await SharedPreferences.getInstance()).getInt(
          'reading_position_reader_page_1',
        ),
        6,
      );
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await render(t);
      expect(find.text('Page 2 of 4'), findsOneWidget);
      await t.tap(find.byTooltip('Previous page'));
      await t.pumpAndSettle();
      await t.tap(find.text('Resume'));
      await t.pumpAndSettle();
      expect(
        calls.lastWhere((c) => c.method == 'speak').arguments,
        'page only.',
      );
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );

  testWidgets('Marathi page controls fit a narrow phone with app theme', (
    t,
  ) async {
    for (final entry in {
      'BuddySans': 'assets/fonts/BuddySans/roboto-regular.ttf',
      'NotoSansDevanagari': 'assets/fonts/NotoSansDevanagari/NotoSansDevanagari.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value))).load();
    }
    await AppLocalizations.setLanguage('mr');
    await render(t, phone: true);
    expect(find.text('4 पैकी पान 1'), findsOneWidget);
    await t.ensureVisible(find.byTooltip('पुढील पान'));
    await t.tap(find.byTooltip('पुढील पान'));
    await t.pumpAndSettle();
    expect(find.text('4 पैकी पान 2'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/16-marathi-pdf-pages.png'));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });


  testWidgets('only current page is spoken; completion never advances pages', (
    t,
  ) async {
    await render(t);
    expect(find.text('Page 1 of 4'), findsOneWidget);
    expect(find.textContaining('3 of 4 pages'), findsOneWidget);
    await t.tap(find.text('Listen'));
    await t.pumpAndSettle();
    expect(
      calls.lastWhere((c) => c.method == 'speak').arguments,
      'First page only.',
    );
    await native('speak.onComplete');
    await t.pumpAndSettle();
    expect(find.text('Page 1 of 4'), findsOneWidget);
    expect(calls.where((c) => c.method == 'speak').length, 1);
    await t.tap(find.byTooltip('Next page'));
    await t.pumpAndSettle();
    expect(find.text('Page 2 of 4'), findsOneWidget);
    await t.tap(find.text('Listen'));
    await t.pumpAndSettle();
    expect(
      calls.lastWhere((c) => c.method == 'speak').arguments,
      'Second page edited.',
    );
    await t.tap(find.byTooltip('Next page'));
    await t.pumpAndSettle();
    expect(find.text('Page 3 of 4'), findsOneWidget);
    expect(find.textContaining('Unreadable scan'), findsOneWidget);
    expect(find.text('Listen'), findsNothing);
    await t.tap(find.byTooltip('Previous page'));
    await t.pumpAndSettle();
    expect(find.text('Page 2 of 4'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
  testWidgets(
    'saved page and per-page progress restore without merged content',
    (t) async {
      SharedPreferences.setMockInitialValues({
        'reading_page_reader': 2,
        'reading_position_reader_page_2': 7,
      });
      await render(t);
      expect(find.text('Page 2 of 4'), findsOneWidget);
      await t.tap(find.text('Resume'));
      await t.pumpAndSettle();
      expect(
        calls.lastWhere((c) => c.method == 'speak').arguments,
        'page edited.',
      );
      await t.tap(find.byTooltip('Previous page'));
      await t.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('reading_position_reader_page_2'), 7);
      expect(prefs.getInt('reading_page_reader'), 1);
      expect(find.text('Page 1 of 4'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
}
