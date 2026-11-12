import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

/// Google's on-device document scanner (Android): finds the page edges,
/// fixes tilt/perspective, removes shadows and stains, auto-rotates.
/// Gives ML Kit a flat, evenly lit page, which is where most camera-photo
/// OCR errors come from.
///
/// The scanner UI is a Google Play services module. It downloads once
/// (needs internet the very first time) and then works offline.
class ScanService {
  /// Returns the cleaned page image, or null if the user closed the scanner.
  /// Throws [ScanUnavailable] if the scanner cannot run on this phone.
  static Future<File?> scanPage() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        mode: ScannerMode.full, // full = shadow/stain removal + filters
        pageLimit: 1,
        isGalleryImport: true,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      final images = result.images ?? const <String>[];
      if (images.isEmpty) return null;
      final file = File(images.first);
      return await file.exists() ? file : null;
    } on PlatformException catch (e) {
      // Closing the scanner is reported as an error by the plugin.
      if ('${e.message}'.toLowerCase().contains('cancel')) return null;
      throw ScanUnavailable(e.message ?? e.code);
    } finally {
      try {
        await scanner.close();
      } catch (_) {}
    }
  }
}

class ScanUnavailable implements Exception {
  final String detail;
  const ScanUnavailable(this.detail);
  @override
  String toString() => 'ScanUnavailable: $detail';
}
