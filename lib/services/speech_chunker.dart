/// Splits text into short utterances for Android TTS.
///
/// Android's TextToSpeech rejects (or silently fails on) a single utterance
/// longer than ~4000 characters, which is why long PDFs/articles produced
/// "Speech is unavailable" even for English. Every chunk's [spoken] string has
/// EXACTLY the same length as the slice `text.substring(start, end)`, so
/// progress offsets reported by the engine map 1:1 back to the original text
/// (needed for word highlighting and resume).
class SpeechChunk {
  const SpeechChunk(this.start, this.end, this.spoken);
  final int start;
  final int end;
  final String spoken;
}

final RegExp _pageMarker = RegExp(
  r'[\u2014\u2013\-_=~]{2,}\s*Page\s+\d+\s*[\u2014\u2013\-_=~]{2,}',
  caseSensitive: false,
);
final RegExp _sentenceEnd = RegExp(
  '[.!?\u0964\u0965\u2026]+["\u201d\u2019)\\]]*(?=\\s|\$)',
);
final RegExp _paragraphBreak = RegExp(r'\n[ \t\r]*\n');
final RegExp _hasWordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Same-length "speakable" version of [text]: page markers become spaces and
/// line breaks/tabs become spaces so wrapped OCR lines are read as one
/// sentence instead of with a pause at every line end.
String speakableText(String text) {
  final blanked = text.replaceAllMapped(
    _pageMarker,
    (m) => ' ' * m.group(0)!.length,
  );
  return blanked.replaceAll(RegExp(r'[\r\n\t\u2028\u2029]'), ' ');
}

List<SpeechChunk> buildSpeechChunks(String text, {int maxChars = 500}) {
  if (maxChars < 2) throw ArgumentError.value(maxChars, 'maxChars');
  if (text.trim().isEmpty) return const [];
  final flat = speakableText(text);
  final cuts = <int>{text.length};
  for (final m in _sentenceEnd.allMatches(flat)) {
    cuts.add(m.end);
  }
  for (final m in _paragraphBreak.allMatches(text)) {
    cuts.add(m.start);
  }
  final sorted = cuts.where((c) => c > 0 && c <= text.length).toList()..sort();

  // Segments (sentences / paragraphs) in order.
  final segments = <List<int>>[];
  var from = 0;
  for (final cut in sorted) {
    if (cut > from) {
      segments.add([from, cut]);
      from = cut;
    }
  }

  // Break over-long segments at whitespace.
  final pieces = <List<int>>[];
  for (final s in segments) {
    var a = s[0];
    final b = s[1];
    while (b - a > maxChars) {
      var cut = a + maxChars;
      final ws = flat.lastIndexOf(' ', cut - 1);
      if (ws > a + maxChars ~/ 2) cut = ws + 1;
      // Never split a UTF-16 surrogate pair (emoji / supplementary letters).
      if (cut < flat.length &&
          flat.codeUnitAt(cut) >= 0xDC00 &&
          flat.codeUnitAt(cut) <= 0xDFFF &&
          flat.codeUnitAt(cut - 1) >= 0xD800 &&
          flat.codeUnitAt(cut - 1) <= 0xDBFF) {
        cut--;
      }
      pieces.add([a, cut]);
      a = cut;
    }
    if (b > a) pieces.add([a, b]);
  }

  // Merge small neighbours (but never across a paragraph break).
  final chunks = <SpeechChunk>[];
  var curStart = -1;
  var curEnd = -1;
  void flush() {
    if (curStart < 0) return;
    final spoken = flat.substring(curStart, curEnd);
    if (_hasWordChar.hasMatch(spoken)) {
      chunks.add(SpeechChunk(curStart, curEnd, spoken));
    }
    curStart = -1;
  }

  for (final p in pieces) {
    if (curStart < 0) {
      curStart = p[0];
      curEnd = p[1];
      continue;
    }
    // Pieces are contiguous; keep a paragraph break as an audible pause.
    final startsParagraph = _paragraphBreak.matchAsPrefix(text, p[0]) != null;
    if (!startsParagraph && (p[1] - curStart) <= maxChars) {
      curEnd = p[1];
    } else {
      flush();
      curStart = p[0];
      curEnd = p[1];
    }
  }
  flush();
  return chunks;
}
