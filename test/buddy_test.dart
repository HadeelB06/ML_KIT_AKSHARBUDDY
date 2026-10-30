import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aksharally_ui/services/buddy_store.dart';
import 'package:aksharally_ui/services/word_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await BuddyStore.load();
  });
  const word = SavedWord(
    word: 'Read',
    language: 'en',
    definition: 'Look at and understand words.',
    example: 'I read a book.',
  );
  test(
    'word saves survive reload and are deduplicated by language and spelling',
    () async {
      await BuddyStore.saveWord(word);
      await BuddyStore.saveWord(word.withKnown(true));
      await BuddyStore.saveWord(
        const SavedWord(
          word: 'Read',
          language: 'hi',
          definition: 'पढ़ना',
          example: 'मैं पढ़ता हूँ।',
        ),
      );
      await BuddyStore.load();
      expect(BuddyStore.words.length, 2);
      expect(
        BuddyStore.words.where((w) => w.language == 'en').single.known,
        true,
      );
      await BuddyStore.removeWord(word.id);
      await BuddyStore.load();
      expect(BuddyStore.words.length, 1);
    },
  );
  test('concurrent updates do not lose words', () async {
    await Future.wait(
      List.generate(
        12,
        (i) => BuddyStore.saveWord(
          SavedWord(
            word: 'word$i',
            language: 'en',
            definition: 'meaning',
            example: 'example',
          ),
        ),
      ),
    );
    await BuddyStore.load();
    expect(BuddyStore.words.length, 12);
  });
  test('streaks use calendar dates and allow today to be unfinished', () async {
    for (final day in [28, 29, 30]) {
      await BuddyStore.addSession(
        ReadingSession(id: '$day', day: '2026-04-$day', seconds: 60, words: 10),
      );
    }
    expect(BuddyStore.currentStreak(DateTime(2026, 5, 1)), 3);
    expect(BuddyStore.currentStreak(DateTime(2026, 5, 2)), 0);
    expect(BuddyStore.bestStreak, 3);
    await BuddyStore.addSession(
      const ReadingSession(
        id: 'may',
        day: '2026-05-01',
        seconds: 120,
        words: 20,
      ),
    );
    expect(BuddyStore.bestStreak, 4);
    expect(BuddyStore.currentStreak(DateTime(2026, 5, 1)), 4);
  });
  test(
    'repeated finish id cannot inflate totals, goals persist and clamp',
    () async {
      const s = ReadingSession(
        id: 'same',
        day: '2026-09-19',
        seconds: 72,
        words: 20,
      );
      await BuddyStore.addSession(s);
      await BuddyStore.addSession(s);
      await BuddyStore.setGoal(100);
      await BuddyStore.load();
      expect(BuddyStore.totalSeconds, 72);
      expect(BuddyStore.totalWords, 20);
      expect(BuddyStore.goalMinutes, 60);
      expect(BuddyStore.secondsOn(DateTime(2026, 9, 19)), 72);
    },
  );
  test('damaged entries do not prevent valid records loading', () async {
    SharedPreferences.setMockInitialValues({
      BuddyStore.storageKey: jsonEncode({
        'words': [{}, word.toJson()],
        'sessions': [{}],
        'goal': 5,
      }),
    });
    await BuddyStore.load();
    expect(BuddyStore.words.length, 1);
    expect(BuddyStore.sessions, isEmpty);
  });
  test('word cleanup preserves Hindi and Marathi combining marks', () {
    expect(WordService.clean('“reading,”'), 'reading');
    expect(WordService.clean('पुस्तक।'), 'पुस्तक');
    expect(WordService.clean('मराठी!'), 'मराठी');
  });
}
