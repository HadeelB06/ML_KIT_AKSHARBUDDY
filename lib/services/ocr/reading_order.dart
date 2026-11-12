/// Pure-Dart reading order for OCR lines.
///
/// * Text pages (textbooks, notices, newspapers): recursive XY-cut. Columns
///   are read top-to-bottom one after another, and a headline that spans
///   columns is read first.
/// * Table-like pages (menus, receipts, timetables): row by row, left to
///   right, cells separated by a tab, so "Paneer Tikka  ₹250" stays together.
library;

import 'dart:math' as math;

class OcrBox {
  final double left, top, right, bottom;
  const OcrBox(this.left, this.top, this.right, this.bottom);
  double get height => (bottom - top).abs();
  double get cy => (top + bottom) / 2;
}

class OrderedText {
  /// Indexes of input lines in reading order, grouped into paragraphs/rows.
  final List<List<int>> groups;
  final bool tableLike;
  const OrderedText(this.groups, this.tableLike);
}

double _median(List<double> v) {
  if (v.isEmpty) return 20;
  final s = [...v]..sort();
  return s[s.length ~/ 2];
}

/// [texts] and [boxes] are parallel lists (one entry per OCR line).
OrderedText orderLines(List<String> texts, List<OcrBox> boxes) {
  final n = boxes.length;
  if (n == 0) return const OrderedText([], false);
  final medH = _median(boxes.map((b) => b.height).where((h) => h > 0).toList());
  final rows = _rows(boxes, medH);
  if (_isTableLike(rows, texts, boxes, medH)) {
    return OrderedText(rows, true);
  }
  final ordered = <List<int>>[];
  _xyCut(List<int>.generate(n, (i) => i), boxes, medH, ordered);
  return OrderedText(ordered, false);
}

/// Group lines whose vertical centres are close into rows, sorted left→right.
List<List<int>> _rows(List<OcrBox> boxes, double medH) {
  final idx = List<int>.generate(boxes.length, (i) => i)
    ..sort((a, b) => boxes[a].cy.compareTo(boxes[b].cy));
  final rows = <List<int>>[];
  final centres = <double>[];
  for (final i in idx) {
    if (rows.isNotEmpty && (boxes[i].cy - centres.last).abs() <= medH * 0.6) {
      rows.last.add(i);
      centres[centres.length - 1] =
          rows.last.map((j) => boxes[j].cy).reduce((a, b) => a + b) / rows.last.length;
    } else {
      rows.add([i]);
      centres.add(boxes[i].cy);
    }
  }
  for (final r in rows) {
    r.sort((a, b) => boxes[a].left.compareTo(boxes[b].left));
  }
  return rows;
}

/// Menus/receipts: many rows split into short cells by a wide gap.
/// Two-column prose also has split rows, but its cells are long sentences.
bool _isTableLike(
  List<List<int>> rows,
  List<String> texts,
  List<OcrBox> boxes,
  double medH,
) {
  if (rows.length < 4) return false;
  var split = 0;
  final cellWords = <double>[];
  for (final r in rows) {
    var hasGap = false;
    for (var k = 1; k < r.length; k++) {
      if (boxes[r[k]].left - boxes[r[k - 1]].right > medH * 1.5) hasGap = true;
    }
    if (hasGap) {
      split++;
      for (final i in r) {
        cellWords.add(texts[i].trim().split(RegExp(r'\s+')).length.toDouble());
      }
    }
  }
  return split / rows.length >= 0.4 && _median(cellWords) <= 3;
}

/// Recursive XY-cut. Prefers a vertical cut (columns); otherwise cuts at the
/// single largest horizontal gap. Leaves are read top→bottom.
void _xyCut(List<int> ids, List<OcrBox> b, double medH, List<List<int>> out) {
  if (ids.length <= 1) {
    if (ids.isNotEmpty) out.add(ids);
    return;
  }
  final v = _largestGap(ids, b, vertical: true);
  if (v != null && v.$2 >= medH * 0.8) {
    final left = ids.where((i) => b[i].right <= v.$1).toList();
    final right = ids.where((i) => b[i].left >= v.$1).toList();
    if (left.length >= 2 && right.length >= 2) {
      _xyCut(left, b, medH, out);
      _xyCut(right, b, medH, out);
      return;
    }
  }
  final h = _largestGap(ids, b, vertical: false);
  if (h != null && h.$2 >= medH * 0.9) {
    final top = ids.where((i) => b[i].bottom <= h.$1).toList();
    final bottom = ids.where((i) => b[i].top >= h.$1).toList();
    if (top.isNotEmpty && bottom.isNotEmpty) {
      _xyCut(top, b, medH, out);
      _xyCut(bottom, b, medH, out);
      return;
    }
  }
  // One paragraph: plain top→bottom, left→right.
  final rows = _rows([for (final i in ids) b[i]], medH);
  out.add([for (final r in rows) for (final k in r) ids[k]]);
}

/// Largest empty strip between projected intervals. Returns (cut position, gap size).
(double, double)? _largestGap(List<int> ids, List<OcrBox> b, {required bool vertical}) {
  final iv = ids
      .map((i) => vertical ? (b[i].left, b[i].right) : (b[i].top, b[i].bottom))
      .toList()
    ..sort((x, y) => x.$1.compareTo(y.$1));
  var end = iv.first.$2;
  (double, double)? best;
  for (var k = 1; k < iv.length; k++) {
    final gap = iv[k].$1 - end;
    if (gap > 0 && (best == null || gap > best.$2)) {
      best = (end + gap / 2, gap);
    }
    if (iv[k].$2 > end) end = iv[k].$2;
  }
  return best;
}

/// Boxes for reading order on a tilted, sideways or upside-down photo.
///
/// On a page photographed at an angle, the upright boxes of neighbouring
/// lines overlap, so rows and columns get mixed up. ML Kit gives each line's
/// four corners in text order (top-left, top-right, bottom-right,
/// bottom-left) and its rotation angle (clockwise positive). The page angle
/// is the circular mean of the line angles (or of the corner-0 to corner-1
/// directions when no angle is reported); every line is rotated back by it
/// and gets a tight upright box. Below [minAngle] degrees the original boxes
/// are returned unchanged.
List<OcrBox> deskewBoxes(
  List<OcrBox> boxes,
  List<List<List<num>>> corners, {
  List<double?>? angles,
  double minAngle = 1.5,
}) {
  if (corners.length != boxes.length) return boxes;
  var sx = 0.0, sy = 0.0;
  // ML Kit's own line angle (degrees, clockwise positive) is preferred.
  for (final a in angles ?? const <double?>[]) {
    if (a == null || !a.isFinite) continue;
    sx += math.cos(a * math.pi / 180);
    sy += math.sin(a * math.pi / 180);
  }
  if (sx == 0 && sy == 0) {
    // Fallback: direction from corner 0 to corner 1 of each line.
    for (final c in corners) {
      if (c.length < 4) continue;
      final dx = (c[1][0] - c[0][0]).toDouble();
      final dy = (c[1][1] - c[0][1]).toDouble();
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 1) continue;
      sx += dx / len;
      sy += dy / len;
    }
  }
  if (sx.abs() < 1e-9 && sy.abs() < 1e-9) return boxes;
  final angle = math.atan2(sy, sx); // radians, clockwise positive (y down)
  if ((angle * 180 / math.pi).abs() < minAngle) return boxes;
  final c = math.cos(-angle), s = math.sin(-angle);
  final out = <OcrBox>[];
  for (var i = 0; i < boxes.length; i++) {
    final pts = corners[i].length >= 4
        ? corners[i]
        : [
            [boxes[i].left, boxes[i].top],
            [boxes[i].right, boxes[i].top],
            [boxes[i].right, boxes[i].bottom],
            [boxes[i].left, boxes[i].bottom],
          ];
    var l = double.infinity, t = double.infinity;
    var r = -double.infinity, b = -double.infinity;
    for (final p in pts) {
      final x = p[0].toDouble(), y = p[1].toDouble();
      final rx = x * c - y * s, ry = x * s + y * c;
      l = math.min(l, rx);
      r = math.max(r, rx);
      t = math.min(t, ry);
      b = math.max(b, ry);
    }
    out.add(OcrBox(l, t, r, b));
  }
  return out;
}
