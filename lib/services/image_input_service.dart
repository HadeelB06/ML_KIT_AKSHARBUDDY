import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'ocr_store.dart';

/// Lossless PNG working copies (photos above ~16 MP are scaled to ~16 MP). Optional enhancement.
/// All edit requests start from the preserved original, never recompressed previews.
Map<String, dynamic> _prepare(Map<String, dynamic> job) {
  final bytes = File(job['source'] as String).readAsBytesSync();
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null) throw StateError('Unsupported image. Choose JPG or PNG.');
  if (info.width * info.height > 120000000) {
    throw StateError('This image is too large to open on this device.');
  }
  final decoded = decoder!.decode(bytes);
  if (decoded == null) throw StateError('Could not decode this image.');
  var image = img.bakeOrientation(decoded);
  // 50/108 MP phone photos used to be rejected here. ML Kit gains nothing
  // beyond ~24 px per character, so scale very large photos down to ~16 MP
  // (still ~4900 px on the long side, plenty for small print) instead.
  const maxPixels = 16000000;
  if (image.width * image.height > maxPixels) {
    final s = math.sqrt(maxPixels / (image.width * image.height));
    image = img.copyResize(
      image,
      width: (image.width * s).round(),
      height: (image.height * s).round(),
      interpolation: img.Interpolation.average,
    );
  }
  final turns = job['turns'] as int;
  if (turns % 4 != 0) image = img.copyRotate(image, angle: (turns % 4) * 90);
  final crop = job['crop'] as List<double>?;
  if (crop != null) {
    final x = (crop[0] * image.width).floor().clamp(0, image.width - 1);
    final y = (crop[1] * image.height).floor().clamp(0, image.height - 1);
    final w = ((crop[2] - crop[0]) * image.width).ceil().clamp(
      1,
      image.width - x,
    );
    final h = ((crop[3] - crop[1]) * image.height).ceil().clamp(
      1,
      image.height - y,
    );
    image = img.copyCrop(image, x: x, y: y, width: w, height: h);
  }
  // Optional, user-chosen working-copy enhancement. The original file is never changed.
  if (job['enhance'] == true) {
    image = img.normalize(img.grayscale(image), min: 0, max: 255);
  }
  File(
    job['target'] as String,
  // Lossless PNG, fastest compression level (level 6 took seconds on 12 MP+).
  ).writeAsBytesSync(img.encodePng(image, level: 1), flush: true);
  final q = _quality(image);
  return {
    'path': job['target'],
    'width': image.width,
    'height': image.height,
    'sharpness': q.$1,
    'brightness': q.$2,
  };
}

/// Photo check on a small grey copy (long side 1000 px):
///  * sharpness = 99.8th percentile of |Laplacian|. Text edges in a sharp
///    photo give strong responses even on a mostly empty page; a blurred
///    photo has none. (Variance would wrongly call sparse pages blurry.)
///  * brightness = mean grey level 0-255.
(double, double) _quality(img.Image src) {
  final long = math.max(src.width, src.height);
  final small = long > 1000
      ? img.copyResize(
          src,
          width: (src.width * 1000 / long).round(),
          height: (src.height * 1000 / long).round(),
          interpolation: img.Interpolation.average,
        )
      : src;
  final w = small.width, h = small.height;
  if (w < 3 || h < 3) return (255.0, 128.0);
  final g = List<double>.filled(w * h, 0);
  var sum = 0.0;
  for (final p in small) {
    final v = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).toDouble();
    g[p.y * w + p.x] = v;
    sum += v;
  }
  final hist = List<int>.filled(1021, 0); // |Laplacian| is at most 1020
  var n = 0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final lap = (g[i - 1] + g[i + 1] + g[i - w] + g[i + w] - 4 * g[i]).abs();
      hist[math.min(lap.round(), 1020)]++;
      n++;
    }
  }
  var acc = 0;
  final cut = (n * 0.998).floor();
  var p998 = 0;
  for (var v = 0; v < hist.length; v++) {
    acc += hist[v];
    if (acc >= cut) {
      p998 = v;
      break;
    }
  }
  return (p998.toDouble(), sum / (w * h));
}

class PreparedImage {
  final String path;
  final int width, height;

  /// Photo check results (null if not measured).
  final double? sharpness, brightness;
  const PreparedImage(
    this.path,
    this.width,
    this.height, {
    this.sharpness,
    this.brightness,
  });

  /// Below these the photo is very likely to give poor OCR.
  static const blurLimit = 35.0, darkLimit = 70.0;

  /// A friendly tip before reading, or null if the photo looks fine.
  /// Advice only: reading is never blocked.
  String? get tip {
    if (sharpness != null && sharpness! < blurLimit) {
      return 'This photo looks blurry. Hold the phone still, tap the text to focus, or use Scan a page.';
    }
    if (brightness != null && brightness! < darkLimit) {
      return 'This photo is quite dark. Add more light, or use Scan a page.';
    }
    return null;
  }
}

class ImageInputService {
  static Future<PreparedImage> prepare(
    String original, {
    int turns = 0,
    List<double>? crop,
    bool enhance = false,
  }) async {
    final dir = await OcrStore.directory();
    final result = await compute(_prepare, <String, dynamic>{
      'source': original,
      'target':
          '${dir.path}/image_${DateTime.now().microsecondsSinceEpoch}.png',
      'turns': turns,
      'crop': crop,
      'enhance': enhance,
    });
    return PreparedImage(
      result['path'] as String,
      result['width'] as int,
      result['height'] as int,
      sharpness: (result['sharpness'] as num?)?.toDouble(),
      brightness: (result['brightness'] as num?)?.toDouble(),
    );
  }
}
