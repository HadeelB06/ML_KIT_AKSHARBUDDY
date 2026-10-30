import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_localizations.dart';

class AssistantVoice {
  static const channel = MethodChannel('aksharbuddy/assistant');
  static Future<List<Map<String, dynamic>>> voices(String language) async {
    final result = await channel.invokeListMethod<dynamic>('voices', {'language': language});
    return (result ?? []).map((v) => Map<String, dynamic>.from(v as Map)).toList();
  }
  static Future<void> speak(String message) async {
    final language = AppLocalizations.language;
    final voice = (await SharedPreferences.getInstance()).getString('assistant_voice_$language');
    await channel.invokeMethod('speak', {'text': tr(message), 'language': language, 'voice': voice});
  }
  static Future<void> stop() async {
    try { await channel.invokeMethod('stop'); } on MissingPluginException { /* Widget tests. */ }
  }
  static Future<String?> selected(String language) async =>
    (await SharedPreferences.getInstance()).getString('assistant_voice_$language');
  static Future<void> select(String language, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = name == null ? await prefs.remove('assistant_voice_$language')
      : await prefs.setString('assistant_voice_$language', name);
    if (!ok) throw StateError('Could not save voice');
  }
}
