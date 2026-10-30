import 'package:flutter/material.dart';

class AppTheme {
  static const lime = Color(0xFF89A886);
  static Color accent(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  static Color cardSurface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  // ════════════════════════════════════════════════════════════════
  // BRAND COLOUR PALETTE
  // ════════════════════════════════════════════════════════════════

  // Primary blue
  static const Color primaryBlue = Color(0xFF526F4D);
  static const Color primaryBlueMid = Color(0xFF526F4D);
  static const Color primaryBlueLight = Color(0xFF526F4D);

  // Cream accent
  static const Color accentCream = Color(0xFFF4F7F1);
  static const Color accentCreamLight = Color(0xFFF4F7F1);

  // Reader highlight yellow
  static const Color highlightYellow = Color(0xFFE3EDCE);
  static const Color highlightYellowLight = Color(0xFFE3EDCE);

  // ── Legacy aliases — preserved for backward compatibility ─────────────────
  // Every file that already uses AppTheme.primaryGreen / AppTheme.lightGrey
  // etc. continues to compile without any change.
  static const Color primaryPink = Color(0xFFE7B5C3);
  static const Color peachButton = Color(0xFFF5A77A);
  static const Color primaryGreen = Color(0xFF526F4D);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color background = Color(0xFFF4F7F1);
  static const Color textDark = Color(0xFF2E2E2E);

  // ════════════════════════════════════════════════════════════════
  // SEMANTIC SURFACE & TEXT TOKENS
  // ════════════════════════════════════════════════════════════════

  // Reading-mode surfaces (Reader screen + Settings preview)
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceSepia = Color(0xFFF4ECD8);

  // Foreground text on each surface
  static const Color onLight = Color(0xFF1A1A1A);
  static const Color onDark = Color(0xFFF5F5F5);

  // Status colours
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFF57C00);

  // Subdued text (timestamps, captions, hints)
  static const Color textMuted = Color(0xFF757575);

  // ════════════════════════════════════════════════════════════════
  // SPACING SCALE
  // ════════════════════════════════════════════════════════════════

  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;

  // ════════════════════════════════════════════════════════════════
  // BORDER RADIUS SCALE
  // ════════════════════════════════════════════════════════════════

  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 20.0;
  static const double radiusXL = 30.0;
  static const double radiusFull = 100.0;

  // ════════════════════════════════════════════════════════════════
  // GRADIENT HELPERS
  //
  // These replace the inline color-list literals repeated across
  // four screen files.  Screens may still define their own local
  // const lists if they need them (backward compatible).
  // ════════════════════════════════════════════════════════════════

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryBlue, primaryBlueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradientVertical = LinearGradient(
    colors: [primaryBlue, primaryBlueLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient creamGradient = LinearGradient(
    colors: [accentCream, accentCreamLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient yellowGradient = LinearGradient(
    colors: [highlightYellow, highlightYellowLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ════════════════════════════════════════════════════════════════
  // TYPOGRAPHY SCALE
  //
  // headingStyle and bodyStyle kept identical to before so existing
  // screens that reference them do not change visually.
  // ════════════════════════════════════════════════════════════════

  // Display — app title / hero
  static const TextStyle displayStyle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w900,
    color: textDark,
    height: 1.2,
    letterSpacing: -0.5,
  );

  // Heading — screen titles, section headers  (unchanged from before)
  static const TextStyle headingStyle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: textDark,
    height: 1.3,
  );

  // Title — card headers, dialog titles
  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: textDark,
    height: 1.4,
  );

  // Label — navigation labels, chips, badges
  static const TextStyle labelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textDark,
    height: 1.4,
  );

  // Body — main content  (unchanged from before)
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textDark,
    height: 1.5,
  );

  // Body Strong — emphasised body text
  static const TextStyle bodyStrongStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textDark,
    height: 1.5,
  );

  // Caption — timestamps, metadata, secondary info
  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textMuted,
    height: 1.4,
  );

  // Button text  (fontSize adjusted 18→16 for better fit; weight unchanged)
  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // ════════════════════════════════════════════════════════════════
  // ACCESSIBILITY CONSTANTS  (WCAG 2.5.5)
  // ════════════════════════════════════════════════════════════════

  /// Minimum recommended touch-target dimension (44 × 44 logical px)
  static const double minTouchTarget = 44.0;

  /// Standard button height
  static const double buttonHeight = 52.0;

  // ════════════════════════════════════════════════════════════════
  // THEME DATA
  // ════════════════════════════════════════════════════════════════

  static ThemeData lightTheme = ThemeData(
    useMaterial3: false,
    scaffoldBackgroundColor: background,
    fontFamily: 'Roboto',

    colorScheme: const ColorScheme.light(
      primary: primaryBlue,
      secondary: primaryGreen,
      surface: surfaceLight,
      error: error,
    ),

    // ── Text theme ──────────────────────────────────────────────
    textTheme: const TextTheme(
      displayLarge: displayStyle,
      headlineMedium: headingStyle,
      titleMedium: titleStyle,
      labelMedium: labelStyle,
      bodyMedium: bodyStyle,
      bodySmall: captionStyle,
    ),

    // ── AppBar ──────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: primaryBlue,
      centerTitle: true,
      titleTextStyle: headingStyle,
    ),

    // ── Cards ───────────────────────────────────────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMD),
      ),
      margin: const EdgeInsets.symmetric(vertical: spaceSM),
    ),

    // ── Elevated buttons ─────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXL),
        ),
        textStyle: buttonTextStyle,
      ),
    ),

    // ── Text fields ──────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLG),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLG),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLG),
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spaceMD,
        vertical: spaceSM + spaceXS,
      ),
      hintStyle: const TextStyle(color: textMuted),
    ),

    // ── Snack bars ───────────────────────────────────────────────
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xFF323232),
      contentTextStyle: TextStyle(color: Colors.white),
    ),

    // ── Sliders (font size / line spacing in Settings) ───────────
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryBlue,
      inactiveTrackColor: primaryBlue.withValues(alpha: 0.2),
      thumbColor: primaryBlue,
      overlayColor: primaryBlue.withValues(alpha: 0.1),
      trackHeight: 4,
    ),

    // ── Dividers ─────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE0E0E0),
      thickness: 1,
      space: 1,
    ),

    // ── Switches (Settings toggles) ──────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? primaryGreen
            : const Color(0xFFBDBDBD),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? primaryGreen.withValues(alpha: 0.4)
            : const Color(0xFFE0E0E0),
      ),
    ),
  );
}
