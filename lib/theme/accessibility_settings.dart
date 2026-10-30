import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Client-side accessibility preferences for the reader (OutputScreen).
///
/// Intentionally separate from [UIAccessibility] (app-wide UI chrome) and
/// [AppSettings] (global/OCR prefs). This class owns only reading-presentation
/// concerns: font, spacing, colours, and accessibility toggles.
///
/// Call [load] once in main() before runApp.
/// Call [save] after any change the user wants to persist.
/// Call [applyPreset] when the user picks mild / moderate / severe.
class AccessibilitySettings {
  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const _kProfile = 'a11y_profile';
  static const _kFont = 'a11y_font';
  static const _kFontSize = 'a11y_fontSize';
  static const _kLetterSp = 'a11y_letterSpacing';
  static const _kWordSp = 'a11y_wordSpacing';
  static const _kLineH = 'a11y_lineHeight';
  static const _kParaSp = 'a11y_paragraphSpacing';
  static const _kColorTheme = 'a11y_colorTheme';
  static const _kWordHL = 'a11y_wordHighlighting';
  static const _kFocusLine = 'a11y_focusLineMode';
  static const _kRuler = 'a11y_readingRuler';
  static const _kSyllable = 'a11y_syllableBreakdown';
  static const _kLargerTap = 'a11y_largerTouchTargets';
  static const _kReduceMot = 'a11y_reduceMotion';

  // ── Live values ───────────────────────────────────────────────────────────
  static double ttsSpeed = 0.4;
  static String profile = 'moderate';
  static String fontFamily = 'System Default';
  static double fontSize = 22.0;
  static double letterSpacing = 1.0;
  static double wordSpacing = 4.0;
  static double lineHeight = 1.8;
  static double paragraphSpacing = 16.0;
  static String colorTheme = 'soft_yellow_black';

  static bool wordHighlighting = true;
  static bool focusLineMode = false;
  static bool readingRuler = false;
  static bool syllableBreakdown = false;
  static bool largerTouchTargets = false;
  static bool reduceMotion = false;

  // ── Presets ───────────────────────────────────────────────────────────────
  static void applyPreset(String p) {
    profile = p;
    switch (p) {
      case 'mild':
        fontFamily = 'System Default';
        fontSize = 18.0;
        letterSpacing = 0.5;
        wordSpacing = 2.0;
        lineHeight = 1.5;
        paragraphSpacing = 12.0;
        colorTheme = 'cream_black';
        break;
      case 'moderate':
        fontFamily = 'System Default';
        fontSize = 22.0;
        letterSpacing = 1.0;
        wordSpacing = 4.0;
        lineHeight = 1.8;
        paragraphSpacing = 16.0;
        colorTheme = 'soft_yellow_black';
        break;
      case 'severe':
        fontFamily = 'OpenDyslexic';
        fontSize = 26.0;
        letterSpacing = 1.5;
        wordSpacing = 6.0;
        lineHeight = 2.2;
        paragraphSpacing = 24.0;
        // white_black (High Contrast) chosen over pale_blue_navy:
        // severe readers need maximum contrast — black-on-white is
        // universally legible and clinically recommended. pale_blue_navy
        // belongs in the Soft Reading category.
        colorTheme = 'white_black';
        break;
      // 'customize': leave values as-is.
    }
  }

  // ── Font families ─────────────────────────────────────────────────────────
  /// Accessibility fonts designed primarily for Latin / English reading.
  static const List<String> englishFonts = ['OpenDyslexic','BuddySans','Lexend','AtkinsonHyperlegible'];
  static const List<String> devanagariFonts = ['NotoSansDevanagari','sans-serif','serif'];

  /// Combined list retained for existing reader code and persistence
  /// compatibility. The customize sheet displays the two categories above.
  static const List<String> fonts = [
    ...englishFonts,
    ...devanagariFonts,
    'System Default', // Plain TextStyle, no font override
  ];

  /// Returns true when the content contains more Devanagari than Latin
  /// letters. Punctuation, spaces, and numbers are intentionally ignored.
  static bool isPrimarilyDevanagari(String text) {
    final devanagariCount = RegExp(r'[\u0900-\u097F]').allMatches(text).length;
    final latinCount = RegExp(r'[A-Za-z]').allMatches(text).length;
    return devanagariCount > latinCount;
  }

  // ── Color themes — 21 themes across 4 categories ─────────────────────────

  static const Map<String, String> themeLabels = {
    // ── Soft Reading
    'cream_black': 'Cream + Black',
    'cream_navy': 'Cream + Navy',
    'soft_yellow_black': 'Soft Yellow + Black',
    'pale_blue_navy': 'Pale Blue + Navy',
    'pale_green_gray': 'Pale Green + Gray',
    'lavender_purple': 'Lavender + Purple',
    // ── High Contrast
    'white_black': 'White + Black',
    'black_white': 'Black + White',
    'white_navy': 'White + Navy',
    'navy_white': 'Navy + White',
    'dark_gray_white': 'Dark Gray + White',
    // ── Extreme Accessibility
    'yellow_black': 'Yellow + Black',
    'black_yellow': 'Black + Yellow',
    'cyan_black': 'Cyan + Black',
    'black_cyan': 'Black + Cyan',
    'dark_blue_yellow': 'Dark Blue + Yellow',
    // ── Modern Reading
    'sepia': 'Sepia',
    'kindle_dark': 'Kindle Dark',
    'slate': 'Slate',
    'graphite': 'Graphite',
    'midnight': 'Midnight',
  };

  static const Map<String, String> themeDescriptions = {
    'cream_black': 'High readability with reduced glare.',
    'cream_navy': 'Strong contrast without harsh black text.',
    'soft_yellow_black': 'Reduces eye strain and improves focus.',
    'pale_blue_navy': 'Helps visual tracking and letter distinction.',
    'pale_green_gray': 'Comfortable for long reading sessions.',
    'lavender_purple': 'Calming contrast with softer tones.',
    'white_black': 'Maximum readability.',
    'black_white': 'Strong contrast for dark reading.',
    'white_navy': 'Cleaner than pure black.',
    'navy_white': 'Dark reading with crisp text.',
    'dark_gray_white': 'Reduced glare dark theme.',
    'yellow_black': 'Maximum foreground/background separation.',
    'black_yellow': 'Frequently preferred by some visually impaired readers.',
    'cyan_black': 'Bright high-visibility theme.',
    'black_cyan': 'Strong visual distinction.',
    'dark_blue_yellow': 'Maximum letter differentiation.',
    'sepia': 'Book-like reading experience.',
    'kindle_dark': 'Comfortable long-session reading.',
    'slate': 'Modern low-glare dark theme.',
    'graphite': 'Balanced dark reading mode.',
    'midnight': 'Pure dark accessibility theme.',
  };

  /// Optional badge for a theme.  Only a few themes carry one.
  static const Map<String, String> themeBadges = {
    'cream_black': 'Dyslexia Recommended',
    'white_black': 'High Contrast',
    'yellow_black': 'Extreme Contrast',
    'sepia': 'Study Mode',
    'kindle_dark': 'Dark Mode',
  };

  /// Theme keys grouped by display category (ordered).
  static const Map<String, List<String>> themeCategories = {
    'Soft Reading': [
      'cream_black',
      'cream_navy',
      'soft_yellow_black',
      'pale_blue_navy',
      'pale_green_gray',
      'lavender_purple',
    ],
    'High Contrast': [
      'white_black',
      'black_white',
      'white_navy',
      'navy_white',
      'dark_gray_white',
    ],
    'Extreme Accessibility': [
      'yellow_black',
      'black_yellow',
      'cyan_black',
      'black_cyan',
      'dark_blue_yellow',
    ],
    'Modern Reading': ['sepia', 'kindle_dark', 'slate', 'graphite', 'midnight'],
  };

  // ── Colours ───────────────────────────────────────────────────────────────

  static Color previewBg(String key) {
    switch (key) {
      // Soft Reading
      case 'cream_black':
        return const Color(0xFFF5F1E6);
      case 'cream_navy':
        return const Color(0xFFF5F1E6);
      case 'soft_yellow_black':
        return const Color(0xFFFFF8C6);
      case 'pale_blue_navy':
        return const Color(0xFFDCEEFF);
      case 'pale_green_gray':
        return const Color(0xFFE8F5E9);
      case 'lavender_purple':
        return const Color(0xFFF2E8FF);
      // High Contrast
      case 'white_black':
        return const Color(0xFFFFFFFF);
      case 'black_white':
        return const Color(0xFF000000);
      case 'white_navy':
        return const Color(0xFFFFFFFF);
      case 'navy_white':
        return const Color(0xFF0A2342);
      case 'dark_gray_white':
        return const Color(0xFF222222);
      // Extreme Accessibility
      case 'yellow_black':
        return const Color(0xFFFFFF00);
      case 'black_yellow':
        return const Color(0xFF000000);
      case 'cyan_black':
        return const Color(0xFFD9FFFF);
      case 'black_cyan':
        return const Color(0xFF000000);
      case 'dark_blue_yellow':
        return const Color(0xFF001F54);
      // Modern Reading
      case 'sepia':
        return const Color(0xFFF4ECD8);
      case 'kindle_dark':
        return const Color(0xFF1B1B1B);
      case 'slate':
        return const Color(0xFF2C3440);
      case 'graphite':
        return const Color(0xFF3A3A3A);
      case 'midnight':
        return const Color(0xFF121212);
      // ── Legacy keys — kept for backward-compat with old SharedPreferences ──
      case 'cream_dark_gray':
        return const Color(0xFFF5F1E6);
      case 'soft_yellow_brown':
        return const Color(0xFFFFF8C6);
      case 'soft_blue_navy':
        return const Color(0xFFDCEEFF);
      case 'mint_dark_gray':
        return const Color(0xFFE8F5E9);
      case 'lavender_dark_gray':
        return const Color(0xFFF2E8FF);
      case 'dark_mode':
        return const Color(0xFF1B1B1B);
      case 'high_contrast':
        return const Color(0xFF000000);
      default:
        return const Color(0xFFFFF8C6);
    }
  }

  static Color previewText(String key) {
    switch (key) {
      case 'cream_black':
        return const Color(0xFF111111);
      case 'cream_navy':
        return const Color(0xFF0A2342);
      case 'soft_yellow_black':
        return const Color(0xFF111111);
      case 'pale_blue_navy':
        return const Color(0xFF001F54);
      case 'pale_green_gray':
        return const Color(0xFF222222);
      case 'lavender_purple':
        return const Color(0xFF4A148C);
      case 'white_black':
        return const Color(0xFF000000);
      case 'black_white':
        return const Color(0xFFFFFFFF);
      case 'white_navy':
        return const Color(0xFF0A2342);
      case 'navy_white':
        return const Color(0xFFFFFFFF);
      case 'dark_gray_white':
        return const Color(0xFFFFFFFF);
      case 'yellow_black':
        return const Color(0xFF000000);
      case 'black_yellow':
        return const Color(0xFFFFFF00);
      case 'cyan_black':
        return const Color(0xFF000000);
      case 'black_cyan':
        return const Color(0xFF00FFFF);
      case 'dark_blue_yellow':
        return const Color(0xFFFFFF00);
      case 'sepia':
        return const Color(0xFF5B4636);
      case 'kindle_dark':
        return const Color(0xFFE6E6E6);
      case 'slate':
        return const Color(0xFFF5F5F5);
      case 'graphite':
        return const Color(0xFFFFFFFF);
      case 'midnight':
        return const Color(0xFFF5F5F5);
      // Legacy
      case 'cream_dark_gray':
        return const Color(0xFF111111);
      case 'soft_yellow_brown':
        return const Color(0xFF111111);
      case 'soft_blue_navy':
        return const Color(0xFF001F54);
      case 'mint_dark_gray':
        return const Color(0xFF222222);
      case 'lavender_dark_gray':
        return const Color(0xFF4A148C);
      case 'dark_mode':
        return const Color(0xFFE6E6E6);
      case 'high_contrast':
        return const Color(0xFFFFFF00);
      default:
        return const Color(0xFF111111);
    }
  }

  static Color backgroundColor() => previewBg(colorTheme);
  static Color textColor() => previewText(colorTheme);

  // ── Persistence ───────────────────────────────────────────────────────────

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    ttsSpeed=(prefs.getDouble('a11y_ttsSpeed')??0.4).clamp(0.1,0.8);
    if (prefs.getString(_kProfile) == null) {
      applyPreset('moderate');
      // A neutral offline font; specialised fonts remain a reader choice.
      fontFamily = 'System Default';
      letterSpacing = 0;
      lineHeight = 1.6;
      syllableBreakdown = false;
      colorTheme = 'cream_black';
      return;
    }
    profile = prefs.getString(_kProfile) ?? 'moderate';
    fontFamily = prefs.getString(_kFont) ?? 'Lexend';
    fontSize = prefs.getDouble(_kFontSize) ?? 22.0;
    letterSpacing = prefs.getDouble(_kLetterSp) ?? 1.0;
    wordSpacing = prefs.getDouble(_kWordSp) ?? 4.0;
    lineHeight = prefs.getDouble(_kLineH) ?? 1.8;
    paragraphSpacing = prefs.getDouble(_kParaSp) ?? 16.0;
    colorTheme = prefs.getString(_kColorTheme) ?? 'soft_yellow_black';
    wordHighlighting = prefs.getBool(_kWordHL) ?? true;
    focusLineMode = prefs.getBool(_kFocusLine) ?? false;
    readingRuler = prefs.getBool(_kRuler) ?? false;
    syllableBreakdown = prefs.getBool(_kSyllable) ?? false;
    largerTouchTargets = prefs.getBool(_kLargerTap) ?? false;
    reduceMotion = prefs.getBool(_kReduceMot) ?? false;
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setDouble('a11y_ttsSpeed',ttsSpeed),
      prefs.setString(_kProfile, profile),
      prefs.setString(_kFont, fontFamily),
      prefs.setDouble(_kFontSize, fontSize),
      prefs.setDouble(_kLetterSp, letterSpacing),
      prefs.setDouble(_kWordSp, wordSpacing),
      prefs.setDouble(_kLineH, lineHeight),
      prefs.setDouble(_kParaSp, paragraphSpacing),
      prefs.setString(_kColorTheme, colorTheme),
      prefs.setBool(_kWordHL, wordHighlighting),
      prefs.setBool(_kFocusLine, focusLineMode),
      prefs.setBool(_kRuler, readingRuler),
      prefs.setBool(_kSyllable, syllableBreakdown),
      prefs.setBool(_kLargerTap, largerTouchTargets),
      prefs.setBool(_kReduceMot, reduceMotion),
    ]);
  }
}
