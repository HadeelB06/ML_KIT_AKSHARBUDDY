import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'ocr_store.dart';

/// Full resolution, lossless PNG working copies. Optional enhancement; no downscaling.
/// All edit requests start from the preserved original, never recompressed previews.
Map<String, dynamic> _prepare(Map<String, dynamic> job) {
  final bytes = File(job['source'] as String).readAsBytesSync();
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null) throw StateError('Unsupported image. Choose JPG or PNG.');
  if (info.width * info.height > 32000000) {
    throw StateError(
      'This image is too large for full-resolution processing on this device. No resizing was applied.',
    );
  }
  final decoded = decoder!.decode(bytes);
  if (decoded == null) throw StateError('Could not decode this image.');
  var image = img.bakeOrientation(decoded);
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
  ).writeAsBytesSync(img.encodePng(image), flush: true);
  return {'path': job['target'], 'width': image.width, 'height': image.height};
}

class PreparedImage {
  final String path;
  final int width, height;
  const PreparedImage(this.path, this.width, this.height);
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
    );
  }
}
