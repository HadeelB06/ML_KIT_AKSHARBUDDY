import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aksharally_ui/services/word_service.dart';
import 'package:aksharally_ui/services/buddy_store.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await BuddyStore.load();
  });
  test('word help uses saved meanings offline and respects language', () async {
    await BuddyStore.saveWord(const SavedWord(word: 'मराठी', language: 'mr', definition: 'माझी नोंद', example: 'उदाहरण'));
    final result = await WordService.lookup('मराठी!', 'mr');
    expect(result.word, 'मराठी');
    expect(result.definition, 'माझी नोंद');
    await expectLater(WordService.lookup('मराठी', 'hi'), throwsFormatException);
  });
  test('unknown words request a personal note without needing a server', () async {
    await expectLater(WordService.lookup('read', 'en'), throwsFormatException);
    expect(WordService.clean('“reading!”'), 'reading');
  });
}
