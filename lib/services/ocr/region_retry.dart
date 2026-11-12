import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Crops suspicious line regions out of the page image and builds two
/// differently-preprocessed versions of each, so ML Kit gets independent
/// second and third reads of only the problem areas.
///
/// Everything happens in ONE background isolate per page: the page is
/// decoded once, every region is cropped from that single decode.
class RetryCrop {
  /// Variant image files (A: contrast-stretched, B: Otsu binarised).
  final List<String> paths;

  /// Height of the variant images in pixels (the target line sits in the middle).
  final int height;
  const RetryCrop(this.paths, this.height);
}

class RegionRetry {
  /// [boxes]: list of {left, top, right, bottom} in page-image pixels.
  /// Returns one [RetryCrop] per box (paths empty if that crop failed).
  static Future<List<RetryCrop>> prepare({
    required String pagePath,
    required List<Map<String, double>> boxes,
    required String workDir,
  }) async {
    if (boxes.isEmpty) return const [];
    try {
      final result = await compute(_crop, <String, dynamic>{
        'page': pagePath,
        'boxes': boxes,
        'dir': workDir,
        'stamp': DateTime.now().microsecondsSinceEpoch.toString(),
      });
      return [
        for (final m in result)
          RetryCrop((m['paths'] as List).cast<String>(), m['height'] as int),
      ];
    } catch (_) {
      return List.generate(boxes.length, (_) => const RetryCrop([], 0));
    }
  }

  /// Enlarges the page so its median line is ~32 px tall (max 3x, max 16 MP).
  /// Returns null if enlarging would not help or failed.
  static Future<UpscaledPage?> upscale({
    required String pagePath,
    required double medianLineHeight,
    required String workDir,
  }) async {
    if (medianLineHeight <= 0) return null;
    try {
      final r = await compute(_upscale, <String, dynamic>{
        'page': pagePath,
        'factor': (32 / medianLineHeight).clamp(1.5, 3.0),
        'target':
            '$workDir/upscaled_${DateTime.now().microsecondsSinceEpoch}.png',
      });
      if (r == null) return null;
      return UpscaledPage(r['path'] as String, r['factor'] as double);
    } catch (_) {
      return null;
    }
  }
}

/// A page image enlarged for small print (screenshots, forwarded photos,
/// far-away shots). ML Kit needs roughly 16-24 px per character.
class UpscaledPage {
  final String path;
  final double factor;
  const UpscaledPage(this.path, this.factor);
}

Map<String, Object>? _upscale(Map<String, dynamic> job) {
  final decoded = img.decodeImage(File(job['page'] as String).readAsBytesSync());
  if (decoded == null) return null;
  final page = img.bakeOrientation(decoded);
  var factor = job['factor'] as double;
  // Keep memory bounded on low-end phones: never exceed ~16 MP.
  const maxPixels = 16000000;
  final area = page.width * page.height;
  if (area * factor * factor > maxPixels) {
    factor = math.sqrt(maxPixels / area);
  }
  if (factor < 1.25) return null; // not worth a second read
  final big = img.copyResize(
    page,
    width: (page.width * factor).round(),
    height: (page.height * factor).round(),
    interpolation: img.Interpolation.cubic,
  );
  final target = job['target'] as String;
  File(target).writeAsBytesSync(img.encodePng(big, level: 1), flush: true);
  // Report the real factor (rounding) so boxes map back exactly.
  return {'path': target, 'factor': big.width / page.width};
}

List<Map<String, Object>> _crop(Map<String, dynamic> job) {
  final bytes = File(job['page'] as String).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw StateError('Could not decode page image.');
  final page = img.bakeOrientation(decoded);
  final boxes = (job['boxes'] as List).cast<Map<String, double>>();
  final dir = job['dir'] as String;
  final stamp = job['stamp'] as String;
  final out = <Map<String, Object>>[];
  for (var i = 0; i < boxes.length; i++) {
    try {
      final b = boxes[i];
      final h = (b['bottom']! - b['top']!).abs().clamp(4.0, 4000.0);
      // Generous padding: matras sit above (ि ी े ै ॅ) and below (ु ू ृ) the line.
      final padY = h * 0.45, padX = h * 0.6;
      final x = (b['left']! - padX).floor().clamp(0, page.width - 1);
      final y = (b['top']! - padY).floor().clamp(0, page.height - 1);
      final r = (b['right']! + padX).ceil().clamp(x + 1, page.width);
      final btm = (b['bottom']! + padY).ceil().clamp(y + 1, page.height);
      var crop = img.copyCrop(page, x: x, y: y, width: r - x, height: btm - y);

      // Upscale small text so a line is ~72 px tall (ML Kit wants >=16-24 px
      // per character; Devanagari matras need more than Latin).
      final scale = (72 / h).clamp(1.0, 4.0);
      if (scale > 1.05) {
        crop = img.copyResize(
          crop,
          width: (crop.width * scale).round(),
          height: (crop.height * scale).round(),
          interpolation: img.Interpolation.cubic,
        );
      }

      // Variant A: grayscale + contrast stretch (fixes low contrast / shadows).
      final a = _border(img.normalize(img.grayscale(img.Image.from(crop)), min: 0, max: 255));
      // Variant B: Otsu binarisation (fixes uneven light, faded print).
      final b2 = _border(_otsu(img.grayscale(img.Image.from(crop))));

      final pa = '$dir/retry_${stamp}_${i}_a.png';
      final pb = '$dir/retry_${stamp}_${i}_b.png';
      File(pa).writeAsBytesSync(img.encodePng(a, level: 1));
      File(pb).writeAsBytesSync(img.encodePng(b2, level: 1));
      out.add({'paths': [pa, pb], 'height': a.height});
    } catch (_) {
      out.add({'paths': <String>[], 'height': 0});
    }
  }
  return out;
}

/// White margin: recognisers read text touching the image edge badly.
img.Image _border(img.Image src) {
  final m = (src.height * 0.25).round().clamp(8, 64);
  final canvas = img.Image(width: src.width + 2 * m, height: src.height + 2 * m);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(canvas, src, dstX: m, dstY: m);
  return canvas;
}

img.Image _otsu(img.Image gray) {
  final hist = List<int>.filled(256, 0);
  for (final p in gray) {
    hist[p.r.toInt().clamp(0, 255)]++;
  }
  final total = gray.width * gray.height;
  var sum = 0.0;
  for (var t = 0; t < 256; t++) {
    sum += t * hist[t];
  }
  var sumB = 0.0, wB = 0, best = 0.0, threshold = 127;
  for (var t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += t * hist[t];
    final mB = sumB / wB, mF = (sum - sumB) / wF;
    final between = wB * wF * (mB - mF) * (mB - mF);
    if (between > best) {
      best = between;
      threshold = t;
    }
  }
  for (final p in gray) {
    final v = p.r > threshold ? 255 : 0;
    p
      ..r = v
      ..g = v
      ..b = v;
  }
  return gray;
}
