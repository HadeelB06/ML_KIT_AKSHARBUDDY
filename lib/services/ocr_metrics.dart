/// Plain-Dart OCR metrics (no Flutter imports) used by tool/ocr_eval.dart.
/// No normalisation beyond whitespace collapsing, so nothing is silently "corrected".
int editDistance<T>(List<T> a, List<T> b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var best = prev[j - 1] + cost;
      if (prev[j] + 1 < best) best = prev[j] + 1;
      if (cur[j - 1] + 1 < best) best = cur[j - 1] + 1;
      cur[j] = best;
    }
    prev = cur;
  }
  return prev[b.length];
}

String collapseWhitespace(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Character error rate over Unicode code points (reference must be non-empty).
double cer(String reference, String hypothesis) {
  final r = collapseWhitespace(reference).runes.toList();
  final h = collapseWhitespace(hypothesis).runes.toList();
  if (r.isEmpty) return h.isEmpty ? 0 : 1;
  return editDistance(r, h) / r.length;
}

double wer(String reference, String hypothesis) {
  final r = collapseWhitespace(
    reference,
  ).split(' ').where((w) => w.isNotEmpty).toList();
  final h = collapseWhitespace(
    hypothesis,
  ).split(' ').where((w) => w.isNotEmpty).toList();
  if (r.isEmpty) return h.isEmpty ? 0 : 1;
  return editDistance(r, h) / r.length;
}
