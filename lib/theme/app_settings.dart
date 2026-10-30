import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static double fontSize = 18;
  static double lineSpacing = 1.5;
  static int themeMode = 0;
  static String language = 'en';
  static String backendUrl = '';
  static const buildBackendUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String normalizeBackendUrl(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleaned.isEmpty) return '';
    final uri = Uri.tryParse(cleaned);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'Enter a complete http:// or https:// server URL.',
      );
    }
    return cleaned;
  }

  static String get effectiveBackendUrl =>
      normalizeBackendUrl(backendUrl.isNotEmpty ? backendUrl : buildBackendUrl);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('app_language');
    language = ['en', 'hi', 'mr'].contains(savedLanguage)
        ? savedLanguage!
        : 'en';
    try {
      backendUrl = normalizeBackendUrl(
        prefs.getString('app_backend_url') ?? '',
      );
    } on FormatException {
      backendUrl = '';
    }
  }

  static Future<void> setLanguage(String value) async {
    if (!['en', 'hi', 'mr'].contains(value)) return;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('app_language', value)) {
      throw StateError('Could not save language. Please try again.');
    }
    language = value;
  }

  static Future<void> setBackendUrl(String value) async {
    final normalized = normalizeBackendUrl(value);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('app_backend_url', normalized)) {
      throw StateError('Could not save the server address. Please try again.');
    }
    backendUrl = normalized;
  }
}
