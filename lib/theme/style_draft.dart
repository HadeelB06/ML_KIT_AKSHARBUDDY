import 'package:flutter/material.dart';
import 'accessibility_settings.dart';
import 'ui_accessibility.dart';

class StyleDraft {
  final bool reader;
  String font, palette;
  double size, letters, words, lines;
  StyleDraft({required this.reader})
    : font = reader ? AccessibilitySettings.fontFamily : UIAccessibility.fontFamily,
      palette = reader ? AccessibilitySettings.colorTheme : UIAccessibility.activeColorTheme,
      size = reader ? AccessibilitySettings.fontSize : UIAccessibility.fontSize,
      letters = reader ? AccessibilitySettings.letterSpacing : UIAccessibility.letterSpacing,
      words = reader ? AccessibilitySettings.wordSpacing : UIAccessibility.wordSpacing,
      lines = reader ? AccessibilitySettings.lineHeight : UIAccessibility.lineHeight;
  static const fonts = ['System Default', 'OpenDyslexic', 'BuddySans', 'Lexend', 'AtkinsonHyperlegible', 'NotoSansDevanagari', 'serif'];
  static String family(String font) => font == 'System Default' ? 'BuddySans' : font;
  Color get background => reader ? AccessibilitySettings.previewBg(palette) : UIAccessibility.themeBg(palette);
  Color get foreground => reader ? AccessibilitySettings.previewText(palette) : UIAccessibility.themeText(palette);
  TextStyle get textStyle => TextStyle(fontFamily: family(font), fontFamilyFallback: const ['NotoSansDevanagari', 'sans-serif'],
    fontSize: size, letterSpacing: letters, wordSpacing: words, height: lines, color: foreground);
  Future<void> apply() async {
    if (reader) {
      AccessibilitySettings.profile = 'customize';
      AccessibilitySettings.fontFamily = font;
      AccessibilitySettings.colorTheme = palette;
      AccessibilitySettings.fontSize = size;
      AccessibilitySettings.letterSpacing = letters;
      AccessibilitySettings.wordSpacing = words;
      AccessibilitySettings.lineHeight = lines;
      await AccessibilitySettings.save();
    } else {
      UIAccessibility.fontFamily = font;
      UIAccessibility.activeColorTheme = palette;
      UIAccessibility.backgroundColor = background;
      UIAccessibility.textColor = foreground;
      UIAccessibility.fontSize = size;
      UIAccessibility.letterSpacing = letters;
      UIAccessibility.wordSpacing = words;
      UIAccessibility.lineHeight = lines;
      await UIAccessibility.save();
      UIAccessibility.notifier.value++;
    }
  }
}
