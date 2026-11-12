/// Pure-Dart rules for the confidence-guided OCR pipeline.
///
/// No Flutter imports, so everything here is unit-testable with `flutter test`.
/// Rules only *flag* text. They never change it.
library;

// ── Unicode helpers ─────────────────────────────────────────────────────────

bool isDevanagari(int r) => r >= 0x0900 && r <= 0x097F;

/// Dependent vowel signs (matras), virama, nukta, anusvara, chandrabindu, visarga.
/// None of these may start a Devanagari word.
bool isDevanagariDependent(int r) =>
    (r >= 0x0900 && r <= 0x0903) ||
    r == 0x093A ||
    r == 0x093B ||
    r == 0x093C ||
    (r >= 0x093E && r <= 0x094F) ||
    (r >= 0x0951 && r <= 0x0957) ||
    r == 0x0962 ||
    r == 0x0963;

/// Dependent vowel signs only (ा ि ी ु ू ृ ॄ ॅ ॆ े ै ॉ ॊ ो ौ).
bool isMatra(int r) => (r >= 0x093E && r <= 0x094C) || r == 0x094E || r == 0x094F;

bool isDevanagariLetter(int r) =>
    (r >= 0x0904 && r <= 0x0939) || (r >= 0x0958 && r <= 0x0961) || r == 0x0972;

bool isDevanagariDigit(int r) => r >= 0x0966 && r <= 0x096F;
bool isAsciiDigit(int r) => r >= 0x30 && r <= 0x39;
bool isLatinLetter(int r) => (r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A);

bool hasDevanagari(String s) => s.runes.any(isDevanagari);
bool hasLatin(String s) => s.runes.any(isLatinLetter);
bool hasDigit(String s) => s.runes.any((r) => isAsciiDigit(r) || isDevanagariDigit(r));

String collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

// ── Suspicion reasons ───────────────────────────────────────────────────────

class Reason {
  static const lowConfidence = 'low_confidence';
  static const mixedScript = 'mixed_script_word';
  static const brokenMatra = 'broken_matra_sequence';
  static const digitLetterMix = 'digit_letter_confusion';
  static const mixedDigits = 'mixed_digit_systems';
  static const badTime = 'invalid_time';
  static const badDate = 'invalid_date';
  static const enginesDisagree = 'engines_disagree';
}

class OcrRuleConfig {
  /// Word below this ML Kit confidence is suspicious (when ML Kit reports one).
  final double wordConfidence;

  /// Line below this ML Kit confidence is suspicious.
  final double lineConfidence;
  const OcrRuleConfig({this.wordConfidence = 0.55, this.lineConfidence = 0.6});
}

/// Suffixes that legitimately sit next to digits ("10am", "2nd", "500ml", "₹50/-").
final _unitSuffix = RegExp(
  r'^(\d+)(am|pm|st|nd|rd|th|kg|gm|g|ml|l|km|cm|mm|m|rs|hrs?|min|mins|sec|pcs|x|%)$',
  caseSensitive: false,
);

/// A digit sitting right next to a letter OCR commonly confuses with a digit.
final _confusable = RegExp(r'\d[OoIlSBZ|]|[OoIlSBZ|]\d');

/// Rules for a single word. Returns the list of reasons (empty = looks fine).
List<String> wordReasons(String word, double? confidence, OcrRuleConfig c) {
  final out = <String>[];
  final w = word.trim();
  if (w.isEmpty) return out;
  if (confidence != null && confidence > 0 && confidence < c.wordConfidence) {
    out.add(Reason.lowConfidence);
  }
  final runes = w.runes.toList();

  // Devanagari and Latin letters inside ONE word almost always means a misread.
  if (runes.any(isDevanagariLetter) && runes.any(isLatinLetter)) {
    out.add(Reason.mixedScript);
  }

  // Broken matra sequences: word starts with a matra/virama/nukta,
  // two matras in a row, or virama directly followed by a matra.
  final firstDeva = runes.indexWhere(isDevanagari);
  if (firstDeva == 0 && isDevanagariDependent(runes[0])) {
    out.add(Reason.brokenMatra);
  } else {
    for (var i = 1; i < runes.length; i++) {
      final a = runes[i - 1], b = runes[i];
      if ((isMatra(a) && isMatra(b)) || (a == 0x094D && isMatra(b))) {
        out.add(Reason.brokenMatra);
        break;
      }
    }
  }

  // ASCII and Devanagari digits mixed inside one number: "१2३".
  if (runes.any(isAsciiDigit) && runes.any(isDevanagariDigit)) {
    out.add(Reason.mixedDigits);
  }

  // Digit/letter confusion: "1O5", "S00", "l0" (but not "10am", "2nd", "5kg").
  final core = w.replaceAll(RegExp(r'^[^\w]+|[^\w%]+$'), '');
  if (core.runes.any(isAsciiDigit) &&
      core.runes.any(isLatinLetter) &&
      !_unitSuffix.hasMatch(core) &&
      _confusable.hasMatch(core)) {
    out.add(Reason.digitLetterMix);
  }
  return out;
}

// Times like "10:30 AM", "10.30 am", "1030 AM", "10530 AM", "25:10".
final _timeAmPm = RegExp(
  r'(?<![\d:.])(\d{1,5})(?:[:.](\d{1,2}))?\s*(a\.?m\.?|p\.?m\.?)(?![a-z])',
  caseSensitive: false,
);
final _time24 = RegExp(r'(?<![\d:.])(\d{1,2}):(\d{1,2})(?![\d:])');
final _date = RegExp(r'(?<![\d/.-])(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})(?![\d/.-])');

/// Rules that need the whole line (numbers, dates, times).
/// Returns map: reason -> matched text, so the UI can highlight exactly that part.
Map<String, String> lineReasons(String line) {
  final out = <String, String>{};
  final ascii = toAsciiDigits(line);
  for (final m in _timeAmPm.allMatches(ascii)) {
    final h = m.group(1)!, mm = m.group(2);
    var ok = true;
    if (mm == null) {
      // "10 AM" is fine. "1030 AM" / "10530 AM" lost the separator: ambiguous.
      ok = h.length <= 2 && int.parse(h) >= 1 && int.parse(h) <= 12;
    } else {
      ok = h.length <= 2 &&
          int.parse(h) >= 1 &&
          int.parse(h) <= 12 &&
          mm.length == 2 &&
          int.parse(mm) <= 59;
    }
    if (!ok) out[Reason.badTime] = line.substring(m.start, m.end);
  }
  for (final m in _time24.allMatches(ascii)) {
    final h = int.parse(m.group(1)!), mm = m.group(2)!;
    if (h > 23 || mm.length != 2 || int.parse(mm) > 59) {
      out[Reason.badTime] = line.substring(m.start, m.end);
    }
  }
  for (final m in _date.allMatches(ascii)) {
    final d = int.parse(m.group(1)!), mo = int.parse(m.group(2)!);
    final y = m.group(3)!;
    if (d < 1 || d > 31 || mo < 1 || mo > 12 || y.length == 3) {
      out[Reason.badDate] = line.substring(m.start, m.end);
    }
  }
  return out;
}

/// Devanagari digits -> ASCII digits, same length (indexes stay valid).
/// Used only for *checking*; the text shown to the user is never converted.
String toAsciiDigits(String s) => String.fromCharCodes(
  s.runes.map((r) => isDevanagariDigit(r) ? 0x30 + (r - 0x0966) : r),
);

/// True if the text carries a number/date/time/price the reader may act on.
bool isImportantNumber(String s) => hasDigit(s);

// ── Consensus between independent reads ─────────────────────────────────────

enum LineStatus { ok, verified, corrected, needsCheck }

class Consensus {
  final LineStatus status;
  final String text; // text to show
  final String? suggestion; // for needsCheck: best alternative, never auto-applied
  final List<String> alternatives;
  const Consensus(this.status, this.text, this.suggestion, this.alternatives);
}

/// Decide what to show for one suspicious line.
///
/// [original] is the first read; [retries] are reads of the same region with
/// other preprocessing / the other engine. Design rule from the brief:
/// never silently change an uncertain number or word.
///  * >=2 reads agree with the original                     -> verified (no warning)
///  * >=2 retry reads agree on a different, rule-clean text -> corrected,
///    UNLESS it involves a number/date/time                 -> needsCheck + suggestion
///  * no agreement                                          -> needsCheck
Consensus decide(
  String original,
  List<String> retries, {
  bool strictNumbers = true,
  OcrRuleConfig config = const OcrRuleConfig(),
}) {
  final o = collapse(original);
  final reads = retries.map(collapse).where((r) => r.isNotEmpty).toList();
  final votes = <String, int>{o: 1};
  for (final r in reads) {
    votes[r] = (votes[r] ?? 0) + 1;
  }
  final alternatives = votes.keys.where((k) => k != o && k.isNotEmpty).toList()
    ..sort((a, b) => votes[b]!.compareTo(votes[a]!));

  if (votes[o]! >= 2 && _clean(o, config)) {
    return Consensus(LineStatus.verified, original, null, alternatives);
  }
  if (alternatives.isNotEmpty) {
    final best = alternatives.first;
    final bestVotes = votes[best]!;
    final clean = _clean(best, config);
    if (bestVotes >= 2 && clean) {
      final numeric = isImportantNumber(best) || isImportantNumber(o);
      if (numeric && strictNumbers) {
        return Consensus(LineStatus.needsCheck, original, best, alternatives);
      }
      return Consensus(LineStatus.corrected, best, null, alternatives);
    }
    return Consensus(
      LineStatus.needsCheck,
      original,
      clean ? best : null,
      alternatives,
    );
  }
  return Consensus(LineStatus.needsCheck, original, null, alternatives);
}

bool _clean(String text, OcrRuleConfig c) =>
    lineReasons(text).isEmpty &&
    text
        .split(' ')
        .every((w) => wordReasons(w, null, c).where((r) => r != Reason.lowConfidence).isEmpty);

// ── Devanagari punctuation ──────────────────────────────────────────────────

final _doubleBar = RegExp(r'\|\s?\|');

/// ML Kit often returns the Devanagari full stop (danda "।", double danda
/// "॥") as a vertical bar "|". Screen readers then say "vertical bar" and the
/// sentence never ends. Only lines that contain Devanagari letters are
/// touched, and only a bar that ends a Devanagari word (followed by a space,
/// a digit or the line end) is converted. Bars in English text are left alone.
String normalizeDanda(String line) {
  if (!line.contains('|') || !line.runes.any(isDevanagariLetter)) return line;
  final s = line.replaceAllMapped(
    _doubleBar,
    (m) => _endsDevanagari(line, m.start) ? '॥' : m[0]!,
  );
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (ch == '|' &&
        _endsDevanagari(s, i) &&
        (i + 1 == s.length || s[i + 1] == ' ' || isAsciiDigit(s.codeUnitAt(i + 1)) ||
            isDevanagariDigit(s.codeUnitAt(i + 1)))) {
      out.write('।');
    } else {
      out.write(ch);
    }
  }
  return out.toString();
}

/// True if the character before [index] (ignoring one space) is Devanagari.
bool _endsDevanagari(String s, int index) {
  var j = index - 1;
  if (j >= 0 && s[j] == ' ') j--;
  return j >= 0 && isDevanagari(s.codeUnitAt(j));
}

// ── PDF text-layer validation ───────────────────────────────────────────────

/// Is a PDF's embedded text layer trustworthy, or is it legacy-font garbage
/// (Kruti Dev: "Hkkjr ljdkj") / scrambled matras / CID junk? If false, the
/// page must be rendered and OCR'd instead.
bool pdfTextLooksUsable(String text, String language) {
  final t = text.trim();
  if (t.isEmpty || t.contains('�')) return false;
  var deva = 0, latin = 0, latin1 = 0, control = 0, devaWords = 0, badStarts = 0;
  for (final r in t.runes) {
    if (isDevanagariLetter(r) || isMatra(r)) deva++;
    if (isLatinLetter(r)) latin++;
    // Latin-1/Extended letters (É, ¨, º …) are typical of broken Indic fonts.
    if ((r >= 0x00C0 && r <= 0x024F) || r == 0x00A8 || r == 0x00BA) latin1++;
    if (r < 0x20 && r != 0x0A && r != 0x0D && r != 0x09 && r != 0x0C) {
      control++;
    }
  }
  final letters = deva + latin + latin1;
  if (letters == 0) return false;
  if (control > 0) return false;
  if (latin1 / letters > 0.08) return false;
  for (final w in t.split(RegExp(r'\s+'))) {
    if (!hasDevanagari(w)) continue;
    devaWords++;
    final first = w.runes.first;
    if (isDevanagariDependent(first)) badStarts++;
  }
  // PDFBox sometimes emits "ि" before its consonant (visual order).
  if (devaWords >= 5 && badStarts / devaWords > 0.04) return false;
  if (language == 'hi' || language == 'mr') {
    // A Hindi/Marathi page that extracts as mostly ASCII letters = legacy font.
    return deva / letters >= 0.35;
  }
  return true;
}
