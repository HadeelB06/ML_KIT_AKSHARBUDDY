import 'package:flutter/material.dart';

import '../theme/accessibility_settings.dart';
import '../theme/app_theme.dart';

/// Paragraph-aware, word-highlighting text renderer.
///
/// Extracted from ReaderScreen (Phase 3A migration) with no behavior
/// changes: same paragraph-marker splitting, same font resolution rules,
/// same highlight color/weight rules. Used by both OutputScreen and ReaderScreen.
class HighlightedTextView extends StatelessWidget {
  /// Raw display text. Only used to detect the "empty" placeholder state —
  /// rendering itself uses [words].
  final String text;

  /// Pre-split word list (see [splitToWords]). Paragraph breaks are
  /// represented by [paragraphMarker] entries and are never rendered as
  /// text or spoken by TTS.
  final List<String> words;

  /// Index into [words] that should be highlighted (e.g. the word currently
  /// being spoken). Pass -1 for no highlight.
  final int currentIndex;
  final ValueChanged<String>? onWordTap;

  const HighlightedTextView({
    super.key,
    required this.text,
    required this.words,
    required this.currentIndex,
    this.onWordTap,
  });

  /// Marks paragraph breaks in the words list (never spoken by TTS).
  static const String paragraphMarker = '¶';

  /// Marks a single source line break so OCR rows and menu items stay
  /// visually separate in the reading view.
  static const String lineBreakMarker = '↵';

  /// Splits raw text into words while retaining paragraph and line breaks.
  ///
  /// Single line breaks are meaningful for OCR output: they can separate
  /// table rows, menu items, headings, and columns. They are kept as markers
  /// rather than silently collapsed into spaces.
  static List<String> splitToWords(String text) {
    final normalized = text.replaceAll('\r\n', '\n');
    final words = <String>[];
    final paragraphs = normalized.split('\n\n');

    for (
      var paragraphIndex = 0;
      paragraphIndex < paragraphs.length;
      paragraphIndex++
    ) {
      final lines = paragraphs[paragraphIndex].split('\n');
      for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        words.addAll(
          lines[lineIndex]
              .split(RegExp(r'[^\S\n]+'))
              .where((word) => word.isNotEmpty),
        );
        if (lineIndex < lines.length - 1) {
          words.add(lineBreakMarker);
        }
      }
      if (paragraphIndex < paragraphs.length - 1) {
        words.add(paragraphMarker);
      }
    }
    return words;
  }

  /// Maps native UTF-16 speech offsets to display words, skipping layout markers.
  static int wordIndexAtOffset(
    String text,
    List<String> words,
    int start,
    int end,
  ) {
    var cursor = 0;
    for (var index = 0; index < words.length; index++) {
      final word = words[index];
      if (word == paragraphMarker || word == lineBreakMarker) continue;
      final position = text.indexOf(word, cursor);
      if (position < 0) continue;
      final wordEnd = position + word.length;
      if (start < wordEnd && end > position) return index;
      cursor = wordEnd;
    }
    return -1;
  }

  /// Returns a [TextStyle] using the font selected in AccessibilitySettings.
  ///
  /// Google Fonts: Lexend, Atkinson Hyperlegible, Noto Sans, Inter, Roboto,
  /// Comic Neue. Platform fonts (Verdana, Tahoma, Arial, Georgia, Trebuchet MS)
  /// use the system font stack with Lexend as fallback.
  /// OpenDyslexic uses the bundled TTF asset (registered in pubspec.yaml).
  /// System Default uses plain TextStyle with no font override.
  TextStyle _resolveFont({
    required double size,
    required double height,
    required double letterSp,
    required double wordSp,
    required Color color,
    FontWeight weight = FontWeight.normal,
  }) {
    final base = TextStyle(
      fontSize: size,
      height: height,
      letterSpacing: letterSp,
      wordSpacing: wordSp,
      color: color,
      fontWeight: weight,
    );
    final selected=AccessibilitySettings.fontFamily;
    return base.copyWith(fontFamily:selected=='OpenDyslexic'?'OpenDyslexic':
      ['serif','Lexend','AtkinsonHyperlegible','NotoSansDevanagari'].contains(selected)?selected:'BuddySans',fontFamilyFallback:const ['NotoSansDevanagari','sans-serif']);
  }

  // ── Word widget ────────────────────────────────────────────────────────────

  Widget _wordWidget(int index, Color textColor) {
    final isHighlighted =
        index == currentIndex && AccessibilitySettings.wordHighlighting;

    // Syllable breakdown is display-only — original words[] list is never mutated.
    final displayWord = words[index];

    final label = Text(
      displayWord,
      style: _resolveFont(
        size: AccessibilitySettings.fontSize,
        height: AccessibilitySettings.lineHeight,
        letterSp: AccessibilitySettings.letterSpacing,
        wordSp: AccessibilitySettings.wordSpacing,
        color: isHighlighted ? const Color(0xFF172219) : textColor,
        weight: FontWeight.normal,
      ).copyWith(backgroundColor: isHighlighted ? AppTheme.lime : null),
    );
    if (onWordTap == null) return label;
    return Semantics(
      button: true,
      label: 'Explain ${words[index]}',
      child: InkWell(
        onTap: () => onWordTap!(words[index]),
        borderRadius: BorderRadius.circular(6),
        child: label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).accessibleNavigation) {
      return SelectableText(
        text,
        style: TextStyle(
          fontSize: AccessibilitySettings.fontSize,
          height: AccessibilitySettings.lineHeight,
          color: AccessibilitySettings.textColor(),
        ),
      );
    }
    final Color textColor = AccessibilitySettings.textColor();

    if (text.isEmpty) {
      return Text(
        'Formatted text will appear here...',
        style: _resolveFont(
          size: AccessibilitySettings.fontSize,
          height: AccessibilitySettings.lineHeight,
          letterSp: AccessibilitySettings.letterSpacing,
          wordSp: AccessibilitySettings.wordSpacing,
          color: textColor.withValues(alpha: 0.5),
        ),
      );
    }

    final double wSpacing = AccessibilitySettings.wordSpacing;
    final double pSpacing = AccessibilitySettings.paragraphSpacing;

    final List<Widget> sections = [];
    List<Widget> currentParagraph = [];

    void flush() {
      if (currentParagraph.isNotEmpty) {
        sections.add(
          Wrap(
            spacing: wSpacing,
            runSpacing: 4.0,
            children: List.from(currentParagraph),
          ),
        );
        currentParagraph = [];
      }
    }

    for (int i = 0; i < words.length; i++) {
      if (words[i] == paragraphMarker) {
        flush();
        sections.add(SizedBox(height: pSpacing));
      } else if (words[i] == lineBreakMarker) {
        flush();
        sections.add(const SizedBox(height: 4));
      } else {
        currentParagraph.add(_wordWidget(i, textColor));
      }
    }
    flush();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: sections,
    );
  }
}
