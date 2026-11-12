import 'dart:convert';
import 'dart:io';
import 'dart:math' show Point;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/ocr_document.dart';
import 'ocr/ocr_rules.dart';
import 'ocr/reading_order.dart';
import 'ocr/region_retry.dart';

/// What the review UI should surface. Lines the pipeline already verified or
/// corrected are never shown as doubtful, even if ML Kit's raw score was low.
class OcrReviewPolicy {
  static const provisionalLowConfidence = 0.5;
  static const provisionalManyLowFraction = 0.35;

  static List<Map<String, dynamic>> doubtfulWords(OcrPage page) => [
    for (final b in page.blocks)
      for (final l in b['lines'] as List)
        if (l['status'] != 'verified' && l['status'] != 'corrected')
          for (final e in l['elements'] as List)
            if (e['suspect'] == true ||
                (l['status'] == null &&
                    e['confidence'] is num &&
                    e['confidence'] < provisionalLowConfidence))
              Map<String, dynamic>.from(e),
  ];

  static bool difficult(OcrPage page) {
    final words = [
      for (final b in page.blocks)
        for (final l in b['lines'] as List) ...l['elements'] as List,
    ].length;
    return words > 0 &&
        doubtfulWords(page).length / words >= provisionalManyLowFraction;
  }

  /// Number of lines still waiting for the reader's confirmation.
  static int linesToCheck(OcrPage page) => [
    for (final b in page.blocks)
      for (final l in b['lines'] as List)
        if (l['status'] == 'needs_check') l,
  ].length;
}

/// Confidence-guided, fully offline OCR for English, Hindi, Marathi and
/// mixed-script text.
///
///  1. Two independent ML Kit reads of the page (Devanagari + Latin model).
///     The Devanagari model also reads English, so mixed menus work whatever
///     language the user picked.
///  2. Line-by-line merge: Devanagari lines come from the Devanagari model,
///     pure English lines from whichever model is more confident, and lines
///     one model missed are added from the other.
///  3. Rules flag suspicious words (broken matras, mixed scripts, digit/letter
///     confusion, impossible times/dates, low confidence, engine disagreement).
///  4. Only suspicious lines are cropped, upscaled, re-processed two ways and
///     read again.
///  5. Voting: agreement -> verified (no warning); clean majority -> corrected;
///     numbers/dates/times are never changed silently -> needs_check with a
///     suggestion; no agreement -> needs_check (highlighted).
///  6. Column-aware reading order (XY-cut), or row order for tables/menus.
class MlkitOcrService {
  static TextRecognizer? _deva;
  static TextRecognizer? _latin;
  static TextRecognizer get _devaR =>
      _deva ??= TextRecognizer(script: TextRecognitionScript.devanagiri);
  static TextRecognizer get _latinR =>
      _latin ??= TextRecognizer(script: TextRecognitionScript.latin);

  /// Max lines re-read per page (keeps a dense page to a few seconds).
  static const maxRetryLines = 16;

  /// Pages whose median line is shorter than this (px) are enlarged once.
  static const smallTextHeight = 20.0;

  /// Latin-only lines on Hindi/Marathi pages need at least this confidence.
  static const latinOnlyConfidence = 0.75;
  static const rules = OcrRuleConfig();
  static final _amPm = RegExp(r'^[ap]\.?m\.?$', caseSensitive: false);

  static TextRecognitionScript scriptFor(String language) => switch (language) {
    'en' => TextRecognitionScript.latin,
    'hi' || 'mr' => TextRecognitionScript.devanagiri,
    _ => throw ArgumentError('Choose English, Hindi or Marathi.'),
  };

  /// Releases the native recognizers (optional).
  static Future<void> dispose() async {
    await _deva?.close();
    await _latin?.close();
    _deva = null;
    _latin = null;
  }

  Future<OcrPage> recognize({
    required String path,
    required String language,
    required String sourceType,
    required String originalPath,
    int pageNumber = 1,
    // Kept for callers; numbers are always protected (see _finalStatus).
    bool importantNumbers = true,
  }) async {
    try {
      if (!Platform.isAndroid) {
        throw UnsupportedError('This build uses Android ML Kit.');
      }
      scriptFor(language); // validates the language code
      final input = InputImage.fromFilePath(path);
      var devaRaw = await _devaR.processImage(input);

      // Small print (screenshots, forwarded photos, far-away shots): ML Kit
      // needs ~16-24 px per character. Enlarge the page once and keep the
      // enlarged read only if it is actually better.
      var readPath = path;
      var scale = 1.0;
      String? upscaledPath;
      final medH = _medianLineHeight(devaRaw);
      if (medH > 0 && medH < smallTextHeight) {
        final up = await RegionRetry.upscale(
          pagePath: path,
          medianLineHeight: medH,
          workDir: Directory.systemTemp.path,
        );
        if (up != null) {
          upscaledPath = up.path;
          final bigRaw = await _devaR.processImage(
            InputImage.fromFilePath(up.path),
          );
          if (_score(bigRaw) > _score(devaRaw)) {
            devaRaw = bigRaw;
            readPath = up.path;
            scale = up.factor;
          }
        }
      }
      final latinRaw = await _latinR.processImage(
        readPath == path ? input : InputImage.fromFilePath(readPath),
      );
      if (upscaledPath != null) {
        try {
          await File(upscaledPath).delete();
        } catch (_) {}
      }
      final deva = _collect(devaRaw, 'devanagari', 1 / scale);
      final latin = _collect(latinRaw, 'latin', 1 / scale);

      final lines = _merge(deva, latin, language);
      _flag(lines);
      await _retry(lines, path, language);
      // Numbers, dates and times are never changed silently, whatever the
      // "important numbers" switch says (that switch only adds a reminder).
      _finalStatus(lines, strictNumbers: true);

      final order = orderLines(
        [for (final l in lines) l.text],
        deskewBoxes(
          [for (final l in lines) l.box],
          [for (final l in lines) l.corners],
          angles: [for (final l in lines) l.angle],
        ),
      );
      final blocks = <Map<String, dynamic>>[];
      final text = StringBuffer();
      for (final group in order.groups) {
        final ls = [for (final i in group) lines[i]];
        final blockText = order.tableLike
            ? ls.map((l) => l.text).join('\t')
            : ls.map((l) => l.text).join('\n');
        if (text.isNotEmpty) text.write(order.tableLike ? '\n' : '\n\n');
        text.write(blockText);
        blocks.add({
          'text': blockText,
          'box': _boxMap(_union(ls.map((l) => l.box))),
          'corners': const [],
          'languages': const [],
          'lines': [for (final l in ls) l.toJson()],
        });
      }
      final raw = text.toString();
      return OcrPage(
        rawOcrText: raw,
        language: language,
        sourceType: sourceType,
        originalPath: originalPath,
        recognitionImagePath: path,
        pageNumber: pageNumber,
        status: raw.trim().isEmpty ? 'empty' : 'complete',
        metadataJson: jsonEncode(blocks),
      );
    } catch (e) {
      return OcrPage(
        rawOcrText: '',
        language: language,
        sourceType: sourceType,
        originalPath: originalPath,
        recognitionImagePath: path,
        pageNumber: pageNumber,
        status: 'failed',
        error: e.toString(),
      );
    }
  }

  // ── 1. Collect ────────────────────────────────────────────────────────────

  static List<_Line> _collect(RecognizedText t, String engine, double k) {
    List<List<num>> pts(List<Point<int>> c) => [
      for (final p in c) <num>[p.x * k, p.y * k],
    ];
    Map<String, double> box(Rect r) => _boxMap(_box(r, k));
    return [
      for (final b in t.blocks)
        for (final l in b.lines)
          if (l.text.trim().isNotEmpty)
            _Line(
              text: normalizeDanda(l.text.trim()),
              mlkitText: l.text,
              box: _box(l.boundingBox, k),
              confidence: l.confidence,
              angle: l.angle,
              corners: pts(l.cornerPoints),
              engine: engine,
              elements: [
                for (final e in l.elements)
                  <String, dynamic>{
                    'text': normalizeDanda(e.text),
                    if (normalizeDanda(e.text) != e.text) 'mlkitText': e.text,
                    'box': box(e.boundingBox),
                    'confidence': e.confidence,
                    'angle': e.angle,
                    'corners': pts(e.cornerPoints),
                  },
              ],
            ),
    ];
  }

  /// Median line height in pixels (0 if nothing was found).
  static double _medianLineHeight(RecognizedText t) {
    final h = [
      for (final b in t.blocks)
        for (final l in b.lines)
          if (l.boundingBox.height > 0) l.boundingBox.height,
    ]..sort();
    return h.isEmpty ? 0.0 : h[h.length ~/ 2];
  }

  /// How much trustworthy text a read produced (characters x confidence).
  static double _score(RecognizedText t) {
    var s = 0.0;
    for (final b in t.blocks) {
      for (final l in b.lines) {
        s += l.text.trim().length * (l.confidence ?? 0.5);
      }
    }
    return s;
  }

  // ── 2. Merge the two engines ──────────────────────────────────────────────

  static List<_Line> _merge(
    List<_Line> deva,
    List<_Line> latin,
    String language,
  ) {
    final out = <_Line>[];
    final usedLatin = <int>{};
    for (final d in deva) {
      var best = -1;
      var bestOv = 0.0;
      for (var j = 0; j < latin.length; j++) {
        final ov = _overlap(d.box, latin[j].box);
        if (ov > bestOv) {
          bestOv = ov;
          best = j;
        }
      }
      if (best < 0 || bestOv < 0.5) {
        out.add(d);
        continue;
      }
      usedLatin.add(best);
      final l = latin[best];
      if (hasDevanagari(d.text)) {
        out.add(d); // only the Devanagari model can read this line
        continue;
      }
      // Pure English / numbers: Latin model unless it is clearly less sure.
      final dc = d.confidence ?? 0, lc = l.confidence ?? 0;
      final pick = dc > lc + 0.1 ? d : l;
      final other = identical(pick, d) ? l : d;
      pick.reads.add(other.text); // second independent read = one more vote
      if (collapse(other.text) != collapse(pick.text)) {
        pick.reasons.add(Reason.enginesDisagree);
      }
      out.add(pick);
    }
    // Lines only the Latin model found (the Devanagari model missed them).
    for (var j = 0; j < latin.length; j++) {
      if (usedLatin.contains(j)) continue;
      final l = latin[j];
      if (out.any((o) => _overlap(o.box, l.box) >= 0.3)) continue;
      // On a Hindi/Marathi page the Latin model turns Devanagari it cannot
      // read into confident-looking junk ("ER fat"). Keep a Latin-only line
      // there only if the Latin model is really sure of it.
      if (language != 'en' && (l.confidence ?? 0) < latinOnlyConfidence) {
        continue;
      }
      out.add(l);
    }
    return out;
  }

  // ── 3. Flag ───────────────────────────────────────────────────────────────

  static void _flag(List<_Line> lines) {
    for (final l in lines) {
      final c = l.confidence;
      if (c != null && c > 0 && c < rules.lineConfidence) {
        l.reasons.add(Reason.lowConfidence);
      }
      final lr = lineReasons(l.text);
      l.reasons.addAll(lr.keys);
      for (final e in l.elements) {
        final t = e['text'] as String;
        final conf = (e['confidence'] as num?)?.toDouble();
        final wr = wordReasons(t, conf, rules);
        // Highlight the number itself (and its AM/PM), not every short word.
        final inBadNumber =
            (hasDigit(t) || _amPm.hasMatch(t)) &&
            lr.values.any((m) => m.contains(t));
        if (wr.isNotEmpty || inBadNumber) {
          e['suspect'] = true;
          e['reasons'] = [...wr, if (inBadNumber) ...lr.keys];
          l.reasons.addAll(wr);
        }
      }
    }
  }

  // ── 4. Re-read only the problem regions ───────────────────────────────────

  static Future<void> _retry(
    List<_Line> lines,
    String path,
    String language,
  ) async {
    final todo = lines.where((l) => l.reasons.isNotEmpty).toList()
      ..sort((a, b) => _priority(b).compareTo(_priority(a)));
    final picked = todo.take(maxRetryLines).toList();
    if (picked.isEmpty) return;
    final crops = await RegionRetry.prepare(
      pagePath: path,
      boxes: [for (final l in picked) _boxMap(l.box)],
      workDir: Directory.systemTemp.path,
    );
    for (var i = 0; i < picked.length && i < crops.length; i++) {
      final line = picked[i];
      final crop = crops[i];
      if (crop.paths.isEmpty) continue;
      line.retried = true;
      final engines = <TextRecognizer>[
        if (hasDevanagari(line.text) || language != 'en') _devaR,
        if (!hasDevanagari(line.text)) _latinR,
      ];
      for (final p in crop.paths) {
        final input = InputImage.fromFilePath(p);
        for (final r in engines) {
          try {
            final read = _centreLine(await r.processImage(input), crop.height);
            if (read.isNotEmpty) line.reads.add(read);
          } catch (_) {
            // A failed retry simply adds no vote.
          }
        }
        try {
          await File(p).delete();
        } catch (_) {}
      }
    }
  }

  static int _priority(_Line l) {
    var p = 0;
    for (final r in l.reasons) {
      p += switch (r) {
        Reason.badTime || Reason.badDate || Reason.mixedDigits => 5,
        Reason.brokenMatra || Reason.mixedScript => 4,
        Reason.digitLetterMix || Reason.enginesDisagree => 3,
        _ => 1,
      };
    }
    return p;
  }

  /// The re-read line is the one closest to the crop's vertical centre
  /// (padding can expose parts of neighbouring lines).
  static String _centreLine(RecognizedText t, int height) {
    final all = [for (final b in t.blocks) ...b.lines];
    if (all.isEmpty) return '';
    final mid = height / 2;
    all.sort(
      (a, b) => (a.boundingBox.center.dy - mid).abs().compareTo(
        (b.boundingBox.center.dy - mid).abs(),
      ),
    );
    final first = all.first.boundingBox;
    final row =
        all
            .where(
              (l) =>
                  (l.boundingBox.center.dy - first.center.dy).abs() <
                  first.height * 0.4,
            )
            .toList()
          ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
    return normalizeDanda(row.map((l) => l.text.trim()).join(' '));
  }

  // ── 5. Decide ─────────────────────────────────────────────────────────────

  static void _finalStatus(List<_Line> lines, {required bool strictNumbers}) {
    for (final l in lines) {
      if (l.reasons.isEmpty) {
        l.status = 'ok';
        continue;
      }
      final d = decide(
        l.text,
        l.reads,
        strictNumbers: strictNumbers,
        config: rules,
      );
      l.alternatives = d.alternatives;
      l.suggestion = d.suggestion;
      switch (d.status) {
        case LineStatus.ok:
        case LineStatus.verified:
          l.status = 'verified';
          for (final e in l.elements) {
            e['suspect'] = false;
          }
        case LineStatus.corrected:
          l.status = 'corrected';
          l.setText(d.text);
        case LineStatus.needsCheck:
          l.status = 'needs_check';
          if (!l.elements.any((e) => e['suspect'] == true)) {
            _markDifferences(l);
          }
          for (final e in l.elements) {
            if (e['suspect'] != true) continue;
            e['lineText'] = l.text;
            e['lineSuggestion'] = l.suggestion;
            e['alternatives'] = l.alternatives;
          }
      }
    }
  }

  /// No specific bad word (e.g. engines disagree / low line confidence):
  /// highlight the words that differ from the best alternative read.
  static void _markDifferences(_Line l) {
    final alt = l.alternatives.isEmpty ? null : l.alternatives.first.split(' ');
    var marked = false;
    for (var i = 0; i < l.elements.length; i++) {
      final e = l.elements[i];
      final t = e['text'] as String;
      final low =
          ((e['confidence'] as num?) ?? 1) < rules.wordConfidence;
      final differs = alt != null && (i >= alt.length || alt[i] != t);
      if (differs || (alt == null && low)) {
        e['suspect'] = true;
        marked = true;
      }
    }
    if (!marked) {
      for (final e in l.elements) {
        e['suspect'] = true;
      }
    }
  }

  // ── Geometry ──────────────────────────────────────────────────────────────

  static OcrBox _box(Rect r, [double k = 1]) =>
      OcrBox(r.left * k, r.top * k, r.right * k, r.bottom * k);

  static Map<String, double> _boxMap(OcrBox b) => {
    'left': b.left,
    'top': b.top,
    'right': b.right,
    'bottom': b.bottom,
  };

  static OcrBox _union(Iterable<OcrBox> bs) {
    var l = double.infinity, t = double.infinity;
    var r = -double.infinity, b = -double.infinity;
    for (final x in bs) {
      if (x.left < l) l = x.left;
      if (x.top < t) t = x.top;
      if (x.right > r) r = x.right;
      if (x.bottom > b) b = x.bottom;
    }
    return OcrBox(l, t, r, b);
  }

  /// Intersection over the smaller box (two engines rarely give identical
  /// line extents).
  static double _overlap(OcrBox a, OcrBox b) {
    final w =
        (a.right < b.right ? a.right : b.right) -
        (a.left > b.left ? a.left : b.left);
    final h =
        (a.bottom < b.bottom ? a.bottom : b.bottom) -
        (a.top > b.top ? a.top : b.top);
    if (w <= 0 || h <= 0) return 0;
    final areaA = (a.right - a.left) * (a.bottom - a.top);
    final areaB = (b.right - b.left) * (b.bottom - b.top);
    final smaller = areaA < areaB ? areaA : areaB;
    return smaller <= 0 ? 0 : (w * h) / smaller;
  }
}

class _Line {
  String text;
  final String mlkitText;
  final OcrBox box;
  final double? confidence;
  final double? angle;
  final List<List<num>> corners;
  final String engine;
  List<Map<String, dynamic>> elements;
  final Set<String> reasons = {};
  final List<String> reads = [];
  List<String> alternatives = const [];
  String? suggestion;
  String status = 'ok';
  bool retried = false;

  _Line({
    required this.text,
    required this.mlkitText,
    required this.box,
    required this.confidence,
    required this.angle,
    required this.corners,
    required this.engine,
    required this.elements,
  });

  Map<String, double> get _boxJson => {
    'left': box.left,
    'top': box.top,
    'right': box.right,
    'bottom': box.bottom,
  };

  /// Apply a verified correction. Word boxes are kept when the word count
  /// matches; otherwise one element covers the whole line. The original
  /// ML Kit words stay in 'mlkitText' so nothing is lost.
  void setText(String value) {
    final words = value.split(' ');
    if (words.length == elements.length) {
      for (var i = 0; i < words.length; i++) {
        elements[i]['mlkitText'] = elements[i]['text'];
        elements[i]['text'] = words[i];
        elements[i]['suspect'] = false;
      }
    } else {
      elements = [
        <String, dynamic>{
          'text': value,
          'mlkitText': text,
          'box': _boxJson,
          'confidence': null,
          'angle': angle,
          'corners': corners,
          'suspect': false,
        },
      ];
    }
    text = value;
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'mlkitText': mlkitText,
    'engine': engine,
    'status': status,
    'reasons': reasons.toList(),
    'retried': retried,
    'suggestion': ?suggestion,
    if (alternatives.isNotEmpty) 'alternatives': alternatives,
    'box': _boxJson,
    'confidence': confidence,
    'angle': angle,
    'corners': corners,
    'elements': elements,
  };
}
