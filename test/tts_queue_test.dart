import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aksharally_ui/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  final calls = <MethodCall>[];
  var offline = true;
  Future<void> event(String name, [dynamic args]) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'flutter_tts',
          const StandardMethodCodec().encodeMethodCall(MethodCall(name, args)),
          (_) {},
        );
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    calls.clear();
    offline = true;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getDefaultEngine') return 'test.engine';
          if (call.method == 'getEngines') return ['test.engine'];
          return 1;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('aksharbuddy/voices'),
          (call) async => offline
              ? [
                  {'name': 'marathi-offline', 'locale': 'mr_IN'},
                ]
              : [],
        );
  });
  test(
    'chunk queue maps progress and completes only after the last chunk',
    () async {
      final service = TTSService();
      var completed = 0;
      int? start;
      service.onComplete = () => completed++;
      service.onProgress = (a, b) => start = a;
      await service.speak(List.filled(260, 'word').join(' '), language: 'mr');
      expect(completed, 0);
      final first =
          calls.lastWhere((c) => c.method == 'speak').arguments as String;
      expect(first.length, lessThanOrEqualTo(500));
      await event('speak.onComplete');
      final second =
          calls.lastWhere((c) => c.method == 'speak').arguments as String;
      await event('speak.onProgress', {
        'text': second,
        'start': '0',
        'end': '4',
        'word': 'word',
      });
      expect(start, first.length);
      expect(completed, 0);
      await event('speak.onComplete');
      await event('speak.onComplete');
      expect(completed, 1);
      expect(service.isSpeaking, isFalse);
      service.dispose();
    },
  );
  test('stop prevents later completion from advancing queue', () async {
    final service = TTSService();
    await service.speak('word ' * 400, language: 'mr');
    await service.stop();
    final count = calls.where((c) => c.method == 'speak').length;
    await event('speak.onComplete');
    expect(calls.where((c) => c.method == 'speak').length, count);
    expect(service.isSpeaking, isFalse);
    service.dispose();
  });
  test(
    'missing offline Marathi voice never falls back to network or Hindi',
    () async {
      offline = false;
      final service = TTSService();
      String? error;
      service.onError = (message) => error = message;
      await service.speak('test', language: 'mr');
      expect(calls.where((c) => c.method == 'speak'), isEmpty);
      expect(error, contains('Marathi'));
      service.dispose();
    },
  );
}
