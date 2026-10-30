import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aksharally_ui/theme/app_settings.dart';
import 'package:aksharally_ui/services/tts_service.dart';
import 'package:aksharally_ui/widgets/highlighted_text_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  final calls = <MethodCall>[];
  var hindiAvailable = true;
  Future<void> native(String event, [Object? args]) async {
    final done = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'flutter_tts',
          const StandardMethodCodec().encodeMethodCall(MethodCall(event, args)),
          (_) => done.complete(),
        );
    await done.future;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    hindiAvailable = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('aksharbuddy/voices'), (
          call,
        ) async {
          return [
            for (final locale in ['en-IN', 'hi-IN', 'mr-IN'])
              {'name': 'offline-$locale', 'locale': locale},
          ];
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'isLanguageAvailable') {
            return !call.arguments.toString().startsWith('hi') ||
                hindiAvailable;
          }
          return 1;
        });
  });

  test(
    'settings survive reload, including Marathi and normalized backend URL',
    () async {
      await AppSettings.setLanguage('mr');
      await AppSettings.setBackendUrl('  http://localhost:5000/  ');
      AppSettings.language = 'en';
      AppSettings.backendUrl = '';
      await AppSettings.load();
      expect(AppSettings.language, 'mr');
      expect(AppSettings.effectiveBackendUrl, 'http://localhost:5000');
      await AppSettings.setLanguage('hi');
      await AppSettings.load();
      expect(AppSettings.language, 'hi');
    },
  );
  test('invalid backend URL does not overwrite saved address', () async {
    await AppSettings.setBackendUrl('https://example.com/backend');
    await expectLater(
      AppSettings.setBackendUrl('192.168.0.10:5000'),
      throwsFormatException,
    );
    expect(AppSettings.backendUrl, 'https://example.com/backend');
    for (final url in [
      'file:///tmp',
      'http://user:password@example.com',
      'http://example.com?q=x',
    ]) {
      expect(() => AppSettings.normalizeBackendUrl(url), throwsFormatException);
    }
  });
  test('offsets preserve repeated words, tabs, CRLF and Devanagari', () {
    const text = 'Read\tthis.\r\n\r\nRead हिंदी मराठी.';
    final words = HighlightedTextView.splitToWords(text);
    expect(words, ['Read', 'this.', '¶', 'Read', 'हिंदी', 'मराठी.']);
    expect(HighlightedTextView.wordIndexAtOffset(text, words, 14, 18), 3);
    final hindi = text.indexOf('हिंदी');
    expect(
      HighlightedTextView.wordIndexAtOffset(text, words, hindi, hindi + 5),
      4,
    );
    expect(HighlightedTextView.wordIndexAtOffset(text, words, 500, 502), -1);
  });
  testWidgets(
    'native speech progress supersedes fallback and completion clears state',
    (tester) async {
      final tts = TTSService();
      final positions = <int>[];
      tts.onProgress = (start, end) => positions.add(start);
      await tts.speak('One two three', language: 'hi');
      expect(
        calls.any((c) => c.method == 'setLanguage' && c.arguments == 'hi-IN'),
        isTrue,
      );
      await native('speak.onStart');
      await tester.pump(const Duration(milliseconds: 410));
      expect(positions, [0]);
      await native('speak.onProgress', {
        'text': 'One two three',
        'start': 4,
        'end': 7,
        'word': 'two',
      });
      await tester.pump(const Duration(seconds: 2));
      expect(positions, [0, 4]);
      await native('speak.onComplete');
      expect(tts.isSpeaking, isFalse);
      tts.dispose();
    },
  );
  testWidgets('fallback scales with selected rate and disposal cancels it', (
    tester,
  ) async {
    final tts = TTSService();
    final positions = <int>[];
    tts.onProgress = (start, end) => positions.add(start);
    await tts.setRate(0.8);
    await tts.speak('One two three', language: 'mr');
    expect(
      calls.any((c) => c.method == 'setLanguage' && c.arguments == 'mr-IN'),
      isTrue,
    );
    await native('speak.onStart');
    await tester.pump(const Duration(milliseconds: 210));
    expect(positions, [0]);
    tts.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(positions, [0]);
  });
  test(
    'missing Hindi voice explains installation without switching language',
    () async {
      hindiAvailable = false;
      final tts = TTSService();
      String? error;
      tts.onError = (value) => error = value;
      await tts.speak('नमस्ते', language: 'hi');
      expect(
        calls.any((c) => c.method == 'setLanguage' && c.arguments == 'en-US'),
        isFalse,
      );
      expect(error, contains('Hindi voice'));
      tts.dispose();
    },
  );
  testWidgets(
    'shared reader preserves line breaks and renders without overflow',
    (tester) async {
      const text = 'Read this.\nहिंदी मराठी\n\nRead again.';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HighlightedTextView(
              text: text,
              words: HighlightedTextView.splitToWords(text),
              currentIndex: 0,
            ),
          ),
        ),
      );
      expect(find.text('हिंदी'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
