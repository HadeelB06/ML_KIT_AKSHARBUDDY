import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/ocr_document.dart';

class OcrReviewPolicy {
  // Provisional UI hint only. Never filters recognition or blocks reading.
  static const provisionalLowConfidence = 0.5;
  static const provisionalManyLowFraction = 0.35;
  static List<Map<String, dynamic>> doubtfulWords(OcrPage page) => [
    for (final b in page.blocks)
      for (final l in b['lines'] as List)
        for (final e in l['elements'] as List)
          if (e['confidence'] is num &&
              e['confidence'] < provisionalLowConfidence)
            Map<String, dynamic>.from(e),
  ];
  static bool difficult(OcrPage page) {
    final words = [
      for (final b in page.blocks)
        for (final l in b['lines'] as List) ...l['elements'] as List,
    ].where((e) => e['confidence'] is num).length;
    return words > 0 &&
        doubtfulWords(page).length / words >= provisionalManyLowFraction;
  }
}

class MlkitOcrService {
  static TextRecognitionScript scriptFor(String language) => switch (language) {
    'en' => TextRecognitionScript.latin,
    'hi' || 'mr' => TextRecognitionScript.devanagiri,
    _ => throw ArgumentError('Choose English, Hindi or Marathi.'),
  };
  static Map<String, double> _box(Rect r) => {
    'left': r.left,
    'top': r.top,
    'right': r.right,
    'bottom': r.bottom,
  };

  Future<OcrPage> recognize({
    required String path,
    required String language,
    required String sourceType,
    required String originalPath,
    int pageNumber = 1,
  }) async {
    TextRecognizer? recognizer;
    try {
      if (!Platform.isAndroid) {
        throw UnsupportedError('This build uses Android ML Kit.');
      }
      recognizer = TextRecognizer(script: scriptFor(language));
      final raw = await recognizer.processImage(InputImage.fromFilePath(path));
      final blocks = raw.blocks
          .map(
            (b) => {
              'text': b.text,
              'box': _box(b.boundingBox),
              'corners': b.cornerPoints.map((p) => [p.x, p.y]).toList(),
              'languages': b.recognizedLanguages,
              'lines': b.lines
                  .map(
                    (l) => {
                      'text': l.text,
                      'box': _box(l.boundingBox),
                      'confidence': l.confidence,
                      'angle': l.angle,
                      'corners': l.cornerPoints.map((p) => [p.x, p.y]).toList(),
                      'elements': l.elements
                          .map(
                            (e) => {
                              'text': e.text,
                              'box': _box(e.boundingBox),
                              'confidence': e.confidence,
                              'angle': e.angle,
                              'corners': e.cornerPoints
                                  .map((p) => [p.x, p.y])
                                  .toList(),
                            },
                          )
                          .toList(),
                    },
                  )
                  .toList(),
            },
          )
          .toList();
      return OcrPage(
        rawOcrText: raw.text,
        language: language,
        sourceType: sourceType,
        originalPath: originalPath,
        recognitionImagePath: path,
        pageNumber: pageNumber,
        status: raw.text.isEmpty ? 'empty' : 'complete',
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
    } finally {
      try {
        await recognizer?.close();
      } catch (_) {
        /* Keep the recognition result even if cleanup fails. */
      }
    }
  }
}
