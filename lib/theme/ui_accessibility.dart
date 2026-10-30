import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI-layer accessibility settings for AksharBuddy.
///
/// Controls how the application interface looks (headings, cards, nav labels,
/// buttons, home screen text, etc.).  It has NO effect on reader content —
/// OCR output, PDF text, simplified text, and OutputScreen rendering remain
/// governed by [AccessibilitySettings].
///
/// Call [load] once in main() before runApp.
/// Call [change] to mutate any field — it persists and fires [notifier].
/// Wrap MaterialApp in `ValueListenableBuilder<int>`(valueListenable:
/// UIAccessibility.notifier) and pass [buildTheme()] as the theme to get
/// instant global propagation without Provider or ChangeNotifier.
class UIAccessibility {
  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const _kInit = 'ui_a11y_initialized';
  static const _kProfile = 'ui_a11y_profile';
  static const _kFont = 'ui_a11y_font';
  static const _kFontSize = 'ui_a11y_fontSize';
  static const _kLetterSp = 'ui_a11y_letterSpacing';
  static const _kWordSp = 'ui_a11y_wordSpacing';
  static const _kLineH = 'ui_a11y_lineHeight';
  static const _kColorTheme = 'ui_a11y_colorTheme';
  static const _kTextColor = 'ui_a11y_textColor';
  static const _kBgColor = 'ui_a11y_bgColor';
  static const _kBoldText = 'ui_a11y_boldText';
  static const _kHighContrast = 'ui_a11y_highContrast';
  static const _kReduceAnim = 'ui_a11y_reduceAnim';
  static const _kLargeTargets = 'ui_a11y_largeTargets';

  // ── Live values ───────────────────────────────────────────────────────────

  static String activeProfile = 'dyslexia';
  static String fontFamily = 'System Default'; // default for first-time users
  static double fontSize = 15.0;
  static double letterSpacing = 0.15;
  static double wordSpacing = 1.0;
  static double lineHeight = 1.6;
  static String activeColorTheme = 'cream';
  static Color textColor = const Color(0xFF333333);
  static Color backgroundColor = const Color(0xFFFDF6E3);

  static bool boldTextEnabled = false;
  static bool highContrastEnabled = false;
  static bool reducedAnimationsEnabled = false;
  static bool largeTouchTargetsEnabled = false;

  // ── Global rebuild notifier ────────────────────────────────────────────────
  /// Increment this to force AksharBuddyApp to rebuild MaterialApp with the
  /// new ThemeData — no Provider or ChangeNotifier needed.
  static final ValueNotifier<int> notifier = ValueNotifier(0);

  // ── Font catalogue ─────────────────────────────────────────────────────────

  static const List<String> fonts = ['System Default','OpenDyslexic','serif','Lexend','AtkinsonHyperlegible','NotoSansDevanagari'];

  // ── Profiles ───────────────────────────────────────────────────────────────

  static const Map<String, String> profileLabels = {
    'dyslexia': 'Everyday comfort',
    'eye_strain': 'Warm page',
    'clarity': 'Large type',
    'beginner': 'Extra space',
  };

  static const Map<String, String> profileDescriptions = {
    'dyslexia': 'Clear type · Warm paper · Room to read',
    'eye_strain': 'Inter · Soft Yellow · Reduced glare',
    'clarity': 'Monospace · White · Large, spaced text',
    'beginner': 'OpenDyslexic · Light Blue · Very large text',
  };

  /// Badges shown on profile cards.
  static const Map<String, String> profileBadges = {
    'dyslexia': 'Everyday comfort',
  };

  /// Applies all fields for the given profile key.
  static void applyProfile(String key) {
    activeProfile = key;
    switch (key) {
      case 'dyslexia':
        fontFamily = 'System Default';
        fontSize = 16.0;
        letterSpacing = 0.15;
        wordSpacing = 1.0;
        lineHeight = 1.6;
        activeColorTheme = 'cream_black';
        textColor = const Color(0xFF20343B);
        backgroundColor = const Color(0xFFF4F7F1);
        break;
      case 'eye_strain':
        fontFamily = 'Inter';
        fontSize = 14.0;
        letterSpacing = 0.2;
        wordSpacing = 1.5;
        lineHeight = 1.5;
        activeColorTheme = 'soft_yellow_black';
        textColor = const Color(0xFF20343B);
        backgroundColor = const Color(0xFFFFF8C6);
        break;
      case 'clarity':
        fontFamily = 'Monospace';
        fontSize = 16.0;
        letterSpacing = 0.5;
        wordSpacing = 3.0;
        lineHeight = 1.8;
        activeColorTheme = 'white_black';
        textColor = const Color(0xFF000000);
        backgroundColor = const Color(0xFFFFFFFF);
        break;
      case 'beginner':
        fontFamily = 'OpenDyslexic';
        fontSize = 18.0;
        letterSpacing = 0.5;
        wordSpacing = 4.0;
        lineHeight = 2.0;
        activeColorTheme = 'pale_blue_navy';
        textColor = const Color(0xFF001F54);
        backgroundColor = const Color(0xFFDCEEFF);
        break;
    }
  }

  // ── Color themes ───────────────────────────────────────────────────────────

  /// Display names for all colour themes.
  static const Map<String, String> colorThemeLabels = {
    'cream_black': 'Cream + Black',
    'soft_yellow_black': 'Soft Yellow + Black',
    'pale_blue_navy': 'Pale Blue + Navy',
    'pale_green_gray': 'Pale Green + Dark Gray',
    'peach_black': 'Peach + Black',
    'white_black': 'White + Black',
    'dark_mode': 'Dark Mode',
    'cream_navy': 'Cream + Navy',
    'cream_dark_green': 'Cream + Dark Green',
    'cream_burgundy': 'Cream + Burgundy',
    'soft_yellow_purple': 'Soft Yellow + Purple',
  };

  /// Short research-backed descriptions for each colour theme.
  static const Map<String, String> colorThemeDescriptions = {
    'cream_black': 'High readability with reduced glare.',
    'soft_yellow_black': 'A warm yellow reading surface.',
    'pale_blue_navy': 'A cool surface with dark navy text.',
    'pale_green_gray': 'Comfortable for long reading sessions.',
    'peach_black': 'Warm tone with strong contrast.',
    'white_black': 'Maximum contrast.',
    'dark_mode': 'Comfortable for low-light environments.',
    'cream_navy': 'Classic cream with deep navy text.',
    'cream_dark_green': 'Earthy tones for reduced eye strain.',
    'cream_burgundy': 'Warm cream with rich burgundy text.',
    'soft_yellow_purple': 'Calming yellow with vivid purple contrast.',
  };

  /// Accessibility badges displayed on theme cards.  A theme may have at
  /// most one badge.
  static const Map<String, String> colorThemeBadges = {
    'cream_black': 'Most Popular',
    'white_black': 'High Contrast',
  };

  static Color themeBg(String key) {
    switch (key) {
      case 'cream_black':
        return const Color(0xFFF4F7F1);
      case 'soft_yellow_black':
        return const Color(0xFFFFF8C6);
      case 'pale_blue_navy':
        return const Color(0xFFDCEEFF);
      case 'pale_green_gray':
        return const Color(0xFFE8F5E9);
      case 'peach_black':
        return const Color(0xFFFFE5D0);
      case 'white_black':
        return const Color(0xFFFFFFFF);
      case 'dark_mode':
        return const Color(0xFF121212);
      case 'cream_navy':
        return const Color(0xFFF4F7F1);
      case 'cream_dark_green':
        return const Color(0xFFF4F7F1);
      case 'cream_burgundy':
        return const Color(0xFFF4F7F1);
      case 'soft_yellow_purple':
        return const Color(0xFFFFF8C6);
      // Legacy keys — kept so old SharedPreferences values degrade gracefully.
      case 'cream':
        return const Color(0xFFF4F7F1);
      case 'soft_yellow':
        return const Color(0xFFFFF8C6);
      case 'light_blue':
        return const Color(0xFFDCEEFF);
      case 'pale_green':
        return const Color(0xFFE8F5E9);
      case 'peach':
        return const Color(0xFFFFE5D0);
      case 'white':
        return const Color(0xFFFFFFFF);
      default:
        return const Color(0xFFF4F7F1);
    }
  }

  static Color themeText(String key) {
    switch (key) {
      case 'cream_black':
        return const Color(0xFF20343B);
      case 'soft_yellow_black':
        return const Color(0xFF20343B);
      case 'pale_blue_navy':
        return const Color(0xFF001F54);
      case 'pale_green_gray':
        return const Color(0xFF222222);
      case 'peach_black':
        return const Color(0xFF20343B);
      case 'white_black':
        return const Color(0xFF000000);
      case 'dark_mode':
        return const Color(0xFFF5F5F5);
      case 'cream_navy':
        return const Color(0xFF0A2342);
      case 'cream_dark_green':
        return const Color(0xFF1B4332);
      case 'cream_burgundy':
        return const Color(0xFF6A040F);
      case 'soft_yellow_purple':
        return const Color(0xFF4C1D95);
      // Legacy keys
      case 'cream':
        return const Color(0xFF20343B);
      case 'soft_yellow':
        return const Color(0xFF20343B);
      case 'light_blue':
        return const Color(0xFF001F54);
      case 'pale_green':
        return const Color(0xFF222222);
      case 'peach':
        return const Color(0xFF20343B);
      case 'white':
        return const Color(0xFF000000);
      default:
        return const Color(0xFF20343B);
    }
  }

  // ── Custom appearance swatches ─────────────────────────────────────────────

  static const List<Color> textSwatches = [
    Color(0xFF1A1A1A),
    Color(0xFF333333),
    Color(0xFF4A3728),
    Color(0xFF1A237E),
    Color(0xFF2E5B2E),
    Color(0xFF880E4F),
    Color(0xFF000000),
    Color(0xFFFFFFFF),
  ];

  static const List<Color> bgSwatches = [
    Color(0xFFF4F7F1),
    Color(0xFFFFF8C6),
    Color(0xFFDCEEFF),
    Color(0xFFE8F5E9),
    Color(0xFFFFE5D0),
    Color(0xFFF3E5F5),
    Color(0xFFFFFFFF),
    Color(0xFF121212),
  ];

  // ── Theme builder ──────────────────────────────────────────────────────────

  /// Builds a complete ThemeData from the current settings.
  /// Pass this to MaterialApp(theme: ...) inside a ValueListenableBuilder.
  static ThemeData buildTheme() {
    final dark = backgroundColor.computeLuminance() < 0.3;
    final primary = dark ? AppTheme.lime : AppTheme.primaryBlue;
    final primaryGreen = primary;
    final onPrimary = dark ? const Color(0xFF172219) : Colors.white;
    final surface = dark ? const Color(0xFF202F35) : const Color(0xFFFFFEFA);
    const errorColor = Color(0xFFD32F2F);
    final muted = textColor.withValues(alpha: 0.75);

    final double btnHeight = largeTouchTargetsEnabled ? 60.0 : 52.0;

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily == 'System Default' ? 'BuddySans' : fontFamily,
      fontFamilyFallback: const ['NotoSansDevanagari', 'sans-serif'],
      visualDensity: VisualDensity.standard,
      chipTheme: ChipThemeData(
        checkmarkColor: onPrimary,
        selectedColor: primary,
        backgroundColor: surface,
        labelStyle: _ts(fontSize, FontWeight.w600, textColor),
        secondaryLabelStyle: _ts(fontSize, FontWeight.w600, onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: const StadiumBorder(),
      ),
      scaffoldBackgroundColor: backgroundColor,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTheme.primaryBlue,
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: primary,
        secondary: primaryGreen,
        surface: surface,
        onSurface: textColor,
        onPrimary: onPrimary,
        error: errorColor,
      ),

      textTheme: TextTheme(
        displayLarge: _ts(fontSize + 18, FontWeight.w900, textColor),
        headlineMedium: _ts(fontSize + 10, FontWeight.bold, textColor),
        titleMedium: _ts(fontSize + 2, FontWeight.w700, textColor),
        labelMedium: _ts(fontSize - 2, FontWeight.w600, textColor),
        bodyMedium: _ts(fontSize, FontWeight.w400, textColor),
        bodySmall: _ts(fontSize - 3, FontWeight.w400, muted),
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: primary,
        centerTitle: true,
        titleTextStyle: _ts(fontSize + 4, FontWeight.w800, primary),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: onPrimary,
          minimumSize: Size(double.infinity, btnHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: _ts(fontSize, FontWeight.w600, onPrimary),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(double.infinity, btnHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: _ts(fontSize, FontWeight.w600, primary),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        hintStyle: TextStyle(color: muted),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: primary.withValues(alpha: 0.2),
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.1),
        trackHeight: 4,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primaryGreen
              : const Color(0xFFBDBDBD),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primaryGreen.withValues(alpha: 0.4)
              : const Color(0xFFE0E0E0),
        ),
      ),

      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF323232),
        contentTextStyle: TextStyle(color: Colors.white),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
        space: 1,
      ),

      // Gradients (stored here for convenience — accessed as
      // Theme.of(context).extension<...>() in future if needed).
      extensions: const [],
    );
  }

  // ── TextStyle factory ──────────────────────────────────────────────────────

  /// Returns a TextStyle for [fontFamily] with Noto Sans as the Devanagari
  /// (Hindi/Marathi) fallback.  OpenDyslexic does not include Devanagari
  /// glyphs; Flutter will automatically pick the next matching fallback.
  static TextStyle _ts(double size, FontWeight weight, Color color) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: boldTextEnabled ? FontWeight.bold : weight,
      color: highContrastEnabled ? _highContrastColor(color) : color,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: lineHeight,
      // Noto Sans covers Devanagari; system sans-serif is the last resort.
      fontFamilyFallback: const ['NotoSansDevanagari', 'sans-serif'],
    );

    if (fontFamily == 'System Default') {
      return base.copyWith(fontFamily: 'BuddySans');
    }
    if (fontFamily == 'OpenDyslexic') {
      return base.copyWith(fontFamily: 'OpenDyslexic');
    }

    return base.copyWith(fontFamily: ['serif','Lexend','AtkinsonHyperlegible','NotoSansDevanagari'].contains(fontFamily)?fontFamily:'BuddySans');
  }

  static Color _highContrastColor(Color c) {
    // In high-contrast mode snap all dark colours to pure black and
    // all light colours to pure white for maximum legibility.
    final lum = c.computeLuminance();
    if (lum < 0.3) return const Color(0xFF000000);
    if (lum > 0.7) return const Color(0xFFFFFFFF);
    return c;
  }


  /// Font labels use a local fallback until that font is selected/downloaded.
  /// Opening Settings must not download the entire optional font catalogue.
  static TextStyle previewStyleFor(String name) {
    const base = TextStyle(fontSize: 13, color: Color(0xFF333333));
    if (name == 'System Default') return base.copyWith(fontFamily: 'BuddySans');
    if (name == 'OpenDyslexic') {
      return base.copyWith(fontFamily: 'OpenDyslexic');
    }
    if (name == fontFamily) return _ts(13, FontWeight.normal, textColor);
    return base.copyWith(
      fontFamily: name,
      fontFamilyFallback: const ['NotoSansDevanagari', 'sans-serif'],
    );
  }

  // ── Mutate helper ──────────────────────────────────────────────────────────

  /// Apply a mutation, increment the notifier, and persist.
  /// Call from any widget that changes a setting.
  static void change(void Function() mutate) {
    mutate();
    notifier.value++;
    save(); // fire-and-forget
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  static void reset() {
    boldTextEnabled = false;
    highContrastEnabled = false;
    reducedAnimationsEnabled = false;
    largeTouchTargetsEnabled = false;
    applyProfile('dyslexia');
    notifier.value++;
    save();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  /// Hydrate from SharedPreferences.  Call once in main() before runApp.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey(_kInit)) {
      // First launch — apply dyslexia defaults and persist so next launch
      // restores exactly these values (existing users keep their saved font).
      applyProfile('dyslexia');
      await save();
      return;
    }

    activeProfile = prefs.getString(_kProfile) ?? 'dyslexia';
    fontFamily = prefs.getString(_kFont) ?? 'OpenDyslexic';
    fontSize = prefs.getDouble(_kFontSize) ?? 15.0;
    letterSpacing = prefs.getDouble(_kLetterSp) ?? 0.3;
    wordSpacing = prefs.getDouble(_kWordSp) ?? 2.0;
    lineHeight = prefs.getDouble(_kLineH) ?? 1.6;
    activeColorTheme = prefs.getString(_kColorTheme) ?? 'cream';
    textColor = Color(prefs.getInt(_kTextColor) ?? 0xFF333333);
    backgroundColor = Color(prefs.getInt(_kBgColor) ?? 0xFFFDF6E3);
    boldTextEnabled = prefs.getBool(_kBoldText) ?? false;
    highContrastEnabled = prefs.getBool(_kHighContrast) ?? false;
    reducedAnimationsEnabled = prefs.getBool(_kReduceAnim) ?? false;
    largeTouchTargetsEnabled = prefs.getBool(_kLargeTargets) ?? false;
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_kInit, true),
      prefs.setString(_kProfile, activeProfile),
      prefs.setString(_kFont, fontFamily),
      prefs.setDouble(_kFontSize, fontSize),
      prefs.setDouble(_kLetterSp, letterSpacing),
      prefs.setDouble(_kWordSp, wordSpacing),
      prefs.setDouble(_kLineH, lineHeight),
      prefs.setString(_kColorTheme, activeColorTheme),
      prefs.setInt(_kTextColor, textColor.toARGB32()),
      prefs.setInt(_kBgColor, backgroundColor.toARGB32()),
      prefs.setBool(_kBoldText, boldTextEnabled),
      prefs.setBool(_kHighContrast, highContrastEnabled),
      prefs.setBool(_kReduceAnim, reducedAnimationsEnabled),
      prefs.setBool(_kLargeTargets, largeTouchTargetsEnabled),
    ]);
  }
}
