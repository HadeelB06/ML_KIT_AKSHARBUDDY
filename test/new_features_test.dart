import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aksharally_ui/theme/app_localizations.dart';
import 'package:aksharally_ui/theme/app_settings.dart';
import 'package:aksharally_ui/theme/accessibility_settings.dart';
import 'package:aksharally_ui/theme/style_draft.dart';
import 'package:aksharally_ui/screens/style_preview_screen.dart';
import 'package:aksharally_ui/screens/splash_screen.dart';
import 'package:aksharally_ui/services/assistant_voice.dart';
import 'package:aksharally_ui/services/tts_service.dart';
import 'package:aksharally_ui/services/voice_command_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocalizations.load();
    await AccessibilitySettings.load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      AssistantVoice.channel, (_) async => null);
  });
  test('Marathi UI persists independently of OCR/reading language', () async {
    AppSettings.language = 'hi';
    await AppLocalizations.setLanguage('mr');
    AppLocalizations.language = 'en';
    await AppLocalizations.load();
    expect(AppLocalizations.language, 'mr');
    expect(tr('Settings'), 'सेटिंग्ज');
    expect(tr('Reading language'), 'वाचनाची भाषा');
    expect(AppSettings.language, 'hi');
    expect(tr('User document content'), 'User document content');
  });
  test('draft preview changes nothing until Apply and saves font', () async {
    final original = AccessibilitySettings.fontFamily;
    final draft = StyleDraft(reader: true)..font = 'NotoSansDevanagari'..size = 28;
    expect(AccessibilitySettings.fontFamily, original);
    await draft.apply();
    AccessibilitySettings.fontFamily = original;
    await AccessibilitySettings.load();
    expect(AccessibilitySettings.fontFamily, 'NotoSansDevanagari');
    expect(AccessibilitySettings.fontSize, 28);
  });
  test('donor commands recognize Marathi, Hindi and English', () {
    expect(VoiceCommandHandler.parse('हे पान वाचा', languageCode: 'mr'), VoiceCommandIntent.readCurrentPage);
    expect(VoiceCommandHandler.parse('धीरे पढ़ें', languageCode: 'hi'), VoiceCommandIntent.decreaseSpeechRate);
    expect(VoiceCommandHandler.parse('resume reading', languageCode: 'en'), VoiceCommandIntent.resumeReading);
  });
  testWidgets('Marathi selection updates visible welcome copy', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.tap(find.text('मराठी'));
    await tester.pumpAndSettle();
    expect(find.text('सुरू करूया'), findsOneWidget);
    expect(find.text('खाते नसताना वापरून पाहा'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('font preview fits a phone and does not apply when closed', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final before = AccessibilitySettings.fontFamily;
    await tester.pumpWidget(const MaterialApp(home: StylePreviewScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lexend'), 300);
    await Scrollable.ensureVisible(tester.element(find.text('Lexend')), alignment: 0.4);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lexend'));
    await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(find.ancestor(of: find.text('Lexend'), matching: find.byType(ListTile))).selected, isTrue);
    await tester.pumpAndSettle();
    expect(AccessibilitySettings.fontFamily, before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(AccessibilitySettings.fontFamily, before);
  });
  test('assistant speech cannot replace reader progress callback', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final readerCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async { readerCalls.add(call); return 1; });
    messenger.setMockMethodCallHandler(const MethodChannel('aksharbuddy/voices'), (_) async => [{'name':'english','locale':'en-IN'}]);
    final reader = TTSService();
    int? progress;
    reader.onProgress = (start, end) => progress = start;
    await reader.speak('one two three', language: 'en');
    final callsBefore = readerCalls.length;
    await AssistantVoice.speak('Hello. I am your reading assistant. Let us read together.');
    expect(readerCalls.length, callsBefore);
    await messenger.handlePlatformMessage('flutter_tts', const StandardMethodCodec().encodeMethodCall(
      const MethodCall('speak.onProgress', {'text':'one two three','start':'4','end':'7','word':'two'})), (_) {});
    await Future<void>.delayed(Duration.zero);
    expect(progress, 4);
    reader.dispose();
  });
}
