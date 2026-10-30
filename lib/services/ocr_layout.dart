import '../models/ocr_document.dart';

class _Ln {
  _Ln(this.text, this.left, this.top, this.right, this.bottom);
  final String text;
  final double left, top, right, bottom;
  double get cy => (top + bottom) / 2;
  double get height => (bottom - top).abs();
}

/// Optional, user-triggered layout reconstruction from ML Kit line boxes.
/// It never touches the raw OCR text; the result is stored as a user edit.
/// Lines that sit on the same horizontal band (e.g. a receipt item name and
/// its qty / price / amount) are joined into one row, left to right.
class OcrLayout {
  static String rows(OcrPage page) {
    final lines = <_Ln>[];
    for (final b in page.blocks) {
      if (b is! Map) continue;
      final ls = b['lines'];
      if (ls is! List) continue;
      for (final l in ls) {
        if (l is! Map) continue;
        final box = l['box'];
        final text = (l['text'] ?? '').toString().trim();
        if (text.isEmpty) continue;
        // Incomplete geometry must not drop recognized content.
        if (box is! Map ||
            ![
              'left',
              'top',
              'right',
              'bottom',
            ].every((k) => box[k] is num && (box[k] as num).isFinite)) {
          return page.displayText;
        }
        double v(String k) => (box[k] as num?)?.toDouble() ?? 0;
        lines.add(_Ln(text, v('left'), v('top'), v('right'), v('bottom')));
      }
    }
    if (lines.isEmpty) return page.rawOcrText;

    final heights = lines.map((l) => l.height).where((h) => h > 0).toList()
      ..sort();
    final median = heights.isEmpty ? 20.0 : heights[heights.length ~/ 2];
    lines.sort((a, b) => a.cy.compareTo(b.cy));

    final rows = <List<_Ln>>[];
    final centres = <double>[];
    for (final l in lines) {
      if (rows.isNotEmpty && (l.cy - centres.last).abs() <= median * 0.6) {
        rows.last.add(l);
        centres[centres.length - 1] =
            rows.last.map((e) => e.cy).reduce((a, b) => a + b) /
            rows.last.length;
      } else {
        rows.add([l]);
        centres.add(l.cy);
      }
    }

    final out = StringBuffer();
    for (final row in rows) {
      row.sort((a, b) => a.left.compareTo(b.left));
      final line = StringBuffer(row.first.text);
      for (var i = 1; i < row.length; i++) {
        final gap = row[i].left - row[i - 1].right;
        line.write(gap > median * 1.5 ? '\t' : ' ');
        line.write(row[i].text);
      }
      out.writeln(line.toString());
    }
    return out.toString().trimRight();
  }
}
