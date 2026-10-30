import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedWord {
  final String word, language, definition, example, source;
  final bool known;
  const SavedWord({
    required this.word,
    required this.language,
    required this.definition,
    required this.example,
    this.source = 'Personal note',
    this.known = false,
  });
  String get id => '$language:${word.toLowerCase()}';
  SavedWord withKnown(bool value) => SavedWord(
    word: word,
    language: language,
    definition: definition,
    example: example,
    source: source,
    known: value,
  );
  Map<String, dynamic> toJson() => {
    'word': word,
    'language': language,
    'definition': definition,
    'example': example,
    'source': source,
    'known': known,
  };
  factory SavedWord.fromJson(Map<String, dynamic> j) => SavedWord(
    word: j['word'] as String,
    language: j['language'] as String,
    definition: j['definition'] as String,
    example: j['example'] as String,
    source: j['source'] as String? ?? 'Personal note',
    known: j['known'] == true,
  );
}

class ReadingSession {
  final String id, day;
  final int seconds, words;
  const ReadingSession({
    required this.id,
    required this.day,
    required this.seconds,
    required this.words,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'seconds': seconds,
    'words': words,
  };
  factory ReadingSession.fromJson(Map<String, dynamic> j) => ReadingSession(
    id: j['id'] as String,
    day: j['day'] as String,
    seconds: j['seconds'] as int,
    words: j['words'] as int,
  );
}

/// Device-local learning records; writes are serialized and publish only on success.
class BuddyStore {
  static const storageKey = 'aksharbuddy_learning_v1';
  static final notifier = ValueNotifier<int>(0);
  static List<SavedWord> _words = [];
  static List<ReadingSession> _sessions = [];
  static int goalMinutes = 5;
  static Future<void>? _writes;
  static List<SavedWord> get words => List.unmodifiable(_words);
  static List<ReadingSession> get sessions => List.unmodifiable(_sessions);
  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static Future<void> load() async {
    _words = [];
    _sessions = [];
    goalMinutes = 5;
    final prefs = await SharedPreferences.getInstance();
    try {
      final data =
          jsonDecode(prefs.getString(storageKey) ?? '{}')
              as Map<String, dynamic>;
      for (final entry in data['words'] as List? ?? []) {
        try {
          final w = SavedWord.fromJson(Map<String, dynamic>.from(entry as Map));
          if (w.word.isNotEmpty &&
              ['en', 'hi', 'mr'].contains(w.language) &&
              !_words.any((x) => x.id == w.id)) {
            _words.add(w);
          }
        } catch (_) {
          /* Skip a damaged record, retain valid records. */
        }
      }
      for (final entry in data['sessions'] as List? ?? []) {
        try {
          final s = ReadingSession.fromJson(
            Map<String, dynamic>.from(entry as Map),
          );
          if (s.seconds > 0 &&
              s.words >= 0 &&
              DateTime.tryParse(s.day) != null &&
              !_sessions.any((x) => x.id == s.id)) {
            _sessions.add(s);
          }
        } catch (_) {
          /* Skip a damaged record. */
        }
      }
      goalMinutes = ((data['goal'] as num?)?.toInt() ?? 5).clamp(1, 60);
    } catch (_) {
      /* Corrupt storage must not prevent opening the app. */
    }
    notifier.value++;
  }

  static Future<void> _commit(
    void Function(List<SavedWord>, List<ReadingSession>) update, {
    int? goal,
  }) {
    Future<void> write() async {
      final words = List<SavedWord>.of(_words),
          sessions = List<ReadingSession>.of(_sessions);
      update(words, sessions);
      final nextGoal = goal?.clamp(1, 60) ?? goalMinutes;
      final prefs = await SharedPreferences.getInstance();
      final ok = await prefs.setString(
        storageKey,
        jsonEncode({
          'words': words.map((w) => w.toJson()).toList(),
          'sessions': sessions.map((s) => s.toJson()).toList(),
          'goal': nextGoal,
        }),
      );
      if (!ok) {
        throw StateError('Could not save on this device. Please try again.');
      }
      _words = words;
      _sessions = sessions;
      goalMinutes = nextGoal;
      notifier.value++;
    }

    final previous = _writes;
    late final Future<void> queued;
    final operation = previous == null
        ? write()
        : previous.then(
            (_) => write(),
            onError: (Object _, StackTrace _) => write(),
          );
    queued = operation.whenComplete(() {
      if (identical(_writes, queued)) _writes = null;
    });
    _writes = queued;
    return queued;
  }

  static Future<void> saveWord(SavedWord word) => _commit((words, _) {
    final index = words.indexWhere((w) => w.id == word.id);
    if (index < 0) {
      words.insert(0, word);
    } else {
      words[index] = word;
    }
  });
  static Future<void> removeWord(String id) =>
      _commit((words, _) => words.removeWhere((w) => w.id == id));
  static Future<void> setGoal(int minutes) => _commit((_, _) {}, goal: minutes);
  static Future<void> addSession(ReadingSession session) =>
      _commit((_, sessions) {
        if (session.seconds > 0 &&
            session.words >= 0 &&
            !sessions.any((s) => s.id == session.id)) {
          sessions.add(session);
        }
      });
  static int secondsOn(DateTime day) => _sessions
      .where((s) => s.day == dayKey(day))
      .fold(0, (n, s) => n + s.seconds);
  static int get totalWords => _sessions.fold(0, (n, s) => n + s.words);
  static int get totalSeconds => _sessions.fold(0, (n, s) => n + s.seconds);
  static int currentStreak(DateTime now) {
    final days = _sessions.map((s) => s.day).toSet();
    var date = DateTime(now.year, now.month, now.day);
    if (!days.contains(dayKey(date))) {
      date = DateTime(date.year, date.month, date.day - 1);
    }
    var count = 0;
    while (days.contains(dayKey(date))) {
      count++;
      date = DateTime(date.year, date.month, date.day - 1);
    }
    return count;
  }

  static int get bestStreak {
    final days = _sessions.map((s) => s.day).toSet().toList()..sort();
    int best = 0, current = 0;
    DateTime? last;
    for (final day in days) {
      final date = DateTime.parse(day);
      current =
          last != null &&
              dayKey(DateTime(last.year, last.month, last.day + 1)) == day
          ? current + 1
          : 1;
      if (current > best) best = current;
      last = date;
    }
    return best;
  }
}
