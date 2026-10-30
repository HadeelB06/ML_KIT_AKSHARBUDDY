import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'translations.dart';

class AppLocalizations {
  static String language = 'en';
  static final notifier = ValueNotifier<int>(0);
  static Future<void> load() async {
    final value = (await SharedPreferences.getInstance()).getString(
      'assistant_ui_language',
    );
    language = ['en', 'hi', 'mr'].contains(value) ? value! : 'en';
  }

  static Future<void> setLanguage(String value) async {
    if (!['en', 'hi', 'mr'].contains(value)) return;
    if (!await (await SharedPreferences.getInstance()).setString(
      'assistant_ui_language',
      value,
    )) {
      throw StateError('Could not save language');
    }
    language = value;
    notifier.value++;
  }

  static String text(String value) {
    if (language == 'en') return value;
    final translated = translations[value];
    return translated == null ? value : translated[language == 'mr' ? 1 : 0];
  }

  static String choose(String english, String hindi, [String? marathi]) =>
      language == 'hi'
      ? hindi
      : language == 'mr'
      ? (marathi ?? text(english))
      : english;
}

String tr(String value) => AppLocalizations.text(value);

mixin LanguageRebuild<T extends StatefulWidget> on State<T> {
  void _languageChanged() { if (mounted) setState(() {}); }
  @override
  void initState() { super.initState(); AppLocalizations.notifier.addListener(_languageChanged); }
  @override
  void dispose() { AppLocalizations.notifier.removeListener(_languageChanged); super.dispose(); }
}

/// Only static UI copy uses this widget. Document text is never translated.
class LText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  final String? semanticsLabel;
  const LText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
    this.semanticsLabel,
  });
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: AppLocalizations.notifier,
    builder: (_, revision, child) => Text(
      tr(data),
      style: style,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
    ),
  );
}

class InterfaceLanguagePicker extends StatelessWidget {
  const InterfaceLanguagePicker({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: AppLocalizations.notifier,
    builder: (context, revision, child) => Wrap(
      spacing: 8,
      runSpacing: 6,
      children: const {'en': 'English', 'hi': 'हिन्दी', 'mr': 'मराठी'}.entries
          .map(
            (entry) => ChoiceChip(
              label: Text(entry.value),
              selected: AppLocalizations.language == entry.key,
              onSelected: (_) async {
                try {
                  await AppLocalizations.setLanguage(entry.key);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr('Could not save your change. Please try again.'),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          )
          .toList(),
    ),
  );
}
