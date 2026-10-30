import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/app_settings.dart';
import 'speech_chunker.dart';

/// Text-to-speech for English, Hindi and Marathi.
///
/// Fixes over the previous version:
///  * Long text is spoken as a queue of short chunks (Android fails on a
///    single utterance of ~4000+ characters).
///  * An installed offline voice is required on Android; missing data prompts
///    a one-time voice download instead of using network speech.
///  * Locale matching is tolerant (hi-IN / hi_IN / hin / hi).
///  * Engine switching compares against the engine actually selected.
///  * Page markers are not read aloud and wrapped OCR lines are read as one
///    sentence. Chunk text keeps the same length as the original, so progress
///    offsets still map exactly onto the displayed text.
class TTSService {
  final FlutterTts _tts = FlutterTts();
  Future<void>? _initialization;
  bool isSpeaking = false;
  bool _disposed = false;
  bool _hasProgress = false;
  double _speechRate = 0.4;
  Timer? _fallback;
  int _generation = 0;
  DateTime _lastOwnStop = DateTime.fromMillisecondsSinceEpoch(0);

  List<SpeechChunk> _chunks = const [];
  int _chunkIndex = 0;
  String _currentSpoken = '';
  int _chunkBase = 0;
  List<RegExpMatch> _ranges = [];
  int _fallbackIndex = 0;
  String _languageName = '';

  void Function(int start, int end)? onProgress;
  VoidCallback? onComplete;
  ValueChanged<String>? onError;

  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    _tts.setStartHandler(() {
      if (_disposed || _currentSpoken.isEmpty) return;
      isSpeaking = true;
      _startFallback();
    });
    _tts.setCompletionHandler(() {
      if (_disposed || !isSpeaking || _currentSpoken.isEmpty) return;
      _chunkIndex++;
      unawaited(_speakCurrent(_generation));
    });
    _tts.setCancelHandler(() {
      // Our own stop() calls finish themselves; ignore the echo of those.
      if (DateTime.now().difference(_lastOwnStop).inMilliseconds < 1500) return;
      _finish();
    });
    _tts.setErrorHandler((message) {
      debugPrint('TTS error: $message');
      _finish();
      if (!_disposed) {
        onError?.call(
          'Speech failed${_languageName.isEmpty ? '' : ' for $_languageName'}. '
          'Open Voice settings, make sure Google Text-to-speech is the engine '
          'and the voice data is installed (internet needed once to download).',
        );
      }
    });
    _tts.setProgressHandler((text, start, end, word) {
      if (_disposed ||
          !isSpeaking ||
          text != _currentSpoken ||
          start < 0 ||
          end <= start) {
        return;
      }
      _hasProgress = true;
      _fallback?.cancel();
      onProgress?.call(_chunkBase + start, _chunkBase + end);
    });
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  static const _voices = MethodChannel('aksharbuddy/voices');
  static Future<void> openVoiceSettings() =>
      _voices.invokeMethod<void>('settings');

  String? _selectedLanguage;
  String? _activeEngine;

  static List<String> _localesFor(String code) {
    switch (code) {
      case 'hi':
        return ['hi-IN', 'hi_IN', 'hi'];
      case 'mr':
        return ['mr-IN', 'mr_IN', 'mr'];
      default:
        return ['en-IN', 'en-US', 'en-GB', 'en'];
    }
  }

  static bool _ok(dynamic r) => r == true || (r is num && r >= 1);

  /// Best offline voice for [code], or null (engine default is then used).
  Future<Map?> _pickOfflineVoice(String? engine, String code) async {
    try {
      final voices = await _voices
          .invokeMethod<List<dynamic>>('offlineVoices', {'engine': engine})
          .timeout(const Duration(seconds: 8));
      if (voices == null) return null;
      Map? best;
      for (final v in voices.whereType<Map>()) {
        final tag = v['locale'].toString().replaceAll('_', '-').toLowerCase();
        final lang = tag.split('-').first;
        final base = lang.length == 3
            ? {'eng': 'en', 'hin': 'hi', 'mar': 'mr'}[lang] ?? lang
            : lang;
        if (base != code) continue;
        if (tag.endsWith('-in')) return v;
        best ??= v;
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  Future<void> _setLanguage(String code) async {
    if (_selectedLanguage == code) return;
    _selectedLanguage = null;
    final diagnostics = <String>[];
    final android = defaultTargetPlatform == TargetPlatform.android;
    dynamic current;
    dynamic engines;
    if (android) {
      try {
        current = await _tts.getDefaultEngine;
        engines = await _tts.getEngines;
      } catch (e) {
        diagnostics.add('engine query error=$e');
      }
    }
    final order = <String?>[];
    final first = _activeEngine ?? (current is String ? current : null);
    order.add(first);
    if (engines is List) {
      final others = engines.whereType<String>().toList();
      // Google's engine first: it is the one that ships hi/mr/en voices.
      others.sort(
        (a, b) =>
            (b == 'com.google.android.tts' ? 1 : 0) -
            (a == 'com.google.android.tts' ? 1 : 0),
      );
      order.addAll(others.where((e) => e != first));
    }

    for (final engine in order) {
      try {
        if (android && engine != null && engine != _activeEngine) {
          if (_activeEngine != null || engine != current) {
            await _tts.setEngine(engine).timeout(const Duration(seconds: 8));
            await Future<void>.delayed(const Duration(milliseconds: 400));
          }
          _activeEngine = engine;
        }
        for (final locale in _localesFor(code)) {
          final available = await _tts.isLanguageAvailable(locale);
          diagnostics.add('engine=$engine locale=$locale available=$available');
          if (!_ok(available)) continue;
          final result = await _tts.setLanguage(locale);
          if (!_ok(result)) continue;
          if (android) {
            final voice = await _pickOfflineVoice(engine, code);
            if (voice != null) {
              final r = await _tts.setVoice({
                'name': voice['name'].toString(),
                'locale': voice['locale'].toString().replaceAll('_', '-'),
              });
              diagnostics.add('voice=${voice['name']} set=$r');
              if (!_ok(r)) continue;
            } else {
              diagnostics.add('no installed offline voice for $code');
              continue;
            }
          }
          _selectedLanguage = code;
          await _saveVoiceDiagnostics(diagnostics);
          return;
        }
      } catch (e) {
        diagnostics.add('engine=$engine error=$e');
      }
    }
    await _saveVoiceDiagnostics(diagnostics);
    final name = _nameOf(code);
    throw StateError(
      'No $name voice found. Open Voice settings > Text-to-speech > Google engine > Install voice data, download "$name (India)", then try Listen again. The download needs internet once.',
    );
  }

  static String _nameOf(String code) =>
      {'en': 'English', 'hi': 'Hindi', 'mr': 'Marathi'}[code] ?? code;

  Future<void> _saveVoiceDiagnostics(List<String> messages) async {
    debugPrint(messages.join('\n'));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tts_last_diagnostics', messages.join('\n'));
    } catch (_) {
      /* Diagnostics must never prevent speech. */
    }
  }

  double get currentRate => _speechRate;
  Future<void> setRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0).toDouble();
    try {
      await init();
      if (_disposed) return;
      await _tts.setSpeechRate(_speechRate);
      if (isSpeaking && !_hasProgress) _startFallback();
    } catch (_) {
      _finish();
      if (!_disposed) {
        onError?.call(
          'Speech is unavailable. Check your device voice settings.',
        );
      }
    }
  }

  void _startFallback() {
    _fallback?.cancel();
    if (_hasProgress || _ranges.isEmpty || _disposed) return;
    // Approximation only: native progress always replaces this timer.
    final interval = Duration(
      milliseconds: (400 * 0.4 / _speechRate).round().clamp(80, 1600),
    );
    _fallback = Timer.periodic(interval, (timer) {
      if (_disposed ||
          !isSpeaking ||
          _hasProgress ||
          _fallbackIndex >= _ranges.length) {
        timer.cancel();
        return;
      }
      final word = _ranges[_fallbackIndex++];
      onProgress?.call(_chunkBase + word.start, _chunkBase + word.end);
    });
  }

  /// Speaks chunk [_chunkIndex]; the completion handler advances the queue.
  Future<void> _speakCurrent(int generation) async {
    if (_disposed || generation != _generation) return;
    if (_chunkIndex >= _chunks.length) {
      _finish();
      return;
    }
    final chunk = _chunks[_chunkIndex];
    _fallback?.cancel();
    _currentSpoken = chunk.spoken;
    _chunkBase = chunk.start;
    _ranges = RegExp(r'\S+').allMatches(chunk.spoken).toList();
    _fallbackIndex = 0;
    _hasProgress = false;
    isSpeaking = true;
    try {
      final result = await _tts.speak(chunk.spoken);
      if (generation != _generation) return;
      if (result == 0 || result == false) {
        _finish();
        onError?.call(
          'The device could not start speech. Check your installed voices.',
        );
      }
    } catch (_) {
      if (generation != _generation) return;
      _finish();
      onError?.call('Speech could not start. Open Voice settings.');
    }
  }

  Future<void> speak(String text, {String? language}) async {
    final generation = ++_generation;
    try {
      await init();
      if (_disposed || generation != _generation) return;
      _finish(notify: false);
      _lastOwnStop = DateTime.now();
      await _tts.stop();
      if (_disposed || generation != _generation) return;
      final code = language ?? AppSettings.language;
      _languageName = _nameOf(code);
      await _setLanguage(code);
      await _tts.setSpeechRate(_speechRate);
      if (_disposed || generation != _generation || text.trim().isEmpty) return;
      _chunks = buildSpeechChunks(text);
      _chunkIndex = 0;
      if (_chunks.isEmpty) return;
      await _speakCurrent(generation);
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _finish();
      if (!_disposed) {
        onError?.call(
          e is StateError
              ? e.message.toString()
              : 'Speech could not start. Open Voice settings and check the installed voice.',
        );
      }
    }
  }

  void _finish({bool notify = true}) {
    isSpeaking = false;
    _fallback?.cancel();
    _currentSpoken = '';
    _chunks = const [];
    _chunkIndex = 0;
    if (!_disposed && notify) onComplete?.call();
  }

  Future<void> stop() async {
    ++_generation;
    _lastOwnStop = DateTime.now();
    _finish();
    try {
      await _tts.stop();
    } catch (_) {
      /* A missing engine is non-fatal. */
    }
  }

  void dispose() {
    _disposed = true;
    onProgress = null;
    onComplete = null;
    onError = null;
    unawaited(stop());
  }
}
