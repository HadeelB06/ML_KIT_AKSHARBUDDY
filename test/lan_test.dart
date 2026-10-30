import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aksharally_ui/services/api_service.dart';
import 'package:aksharally_ui/services/library_storage.dart';
import 'package:aksharally_ui/models/library_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('legacy LAN entry points remain disabled in local ML Kit build', () async {
    await expectLater(ApiService.checkConnection(), throwsUnsupportedError);
    await expectLater(ApiService.processImage(File('not-uploaded.png')), throwsUnsupportedError);
  });

  test('continue card follows last opened item and survives reload', () async {
    SharedPreferences.setMockInitialValues({});
    await LibraryStorage.load();
    final first = LibraryItem(
      title: 'First',
      content: 'First',
      date: DateTime(2026, 1, 1),
      sourceType: 'text',
      language: 'en',
    );
    final second = LibraryItem(
      title: 'Second',
      content: 'Second',
      date: DateTime(2026, 1, 2),
      sourceType: 'text',
      language: 'en',
    );
    LibraryStorage.addItem(first);
    LibraryStorage.addItem(second);
    await LibraryStorage.markOpened(first.date.toIso8601String());
    expect(LibraryStorage.continueReading().single.title, 'First');
    await LibraryStorage.load();
    expect(LibraryStorage.continueReading().single.title, 'First');
  });
}
