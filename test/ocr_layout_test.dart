import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aksharally_ui/models/ocr_document.dart';
import 'package:aksharally_ui/services/ocr_layout.dart';

void main() {
  Map<String, dynamic> line(String text, double left, double top) => {
    'text': text,
    'box': {'left': left, 'top': top, 'right': left + 30, 'bottom': top + 10},
  };
  OcrPage page(List<dynamic> lines) => OcrPage(
    rawOcrText: 'Z693.00\nName 17/10/2026\n123',
    language: 'en',
    sourceType: 'gallery',
    originalPath: 'original.jpg',
    metadataJson: jsonEncode([
      {'lines': lines},
    ]),
  );
  test(
    'arrangement preserves currency-like characters, dates and raw source',
    () {
      final original = page([
        line('Z693.00', 100, 10),
        line('Name 17/10/2026', 0, 10),
        line('123', 0, 30),
      ]);
      final edited = original.edited(OcrLayout.rows(original));
      expect(edited.displayText, 'Name 17/10/2026\tZ693.00\n123');
      expect(edited.rawOcrText, original.rawOcrText);
      expect(edited.metadataJson, original.metadataJson);
      expect(edited.originalPath, original.originalPath);
    },
  );
  test('missing geometry preserves all text instead of dropping a line', () {
    final original = page([
      line('Z693.00', 100, 10),
      {'text': 'Name 17/10/2026'},
    ]);
    expect(OcrLayout.rows(original), original.displayText);
  });
}
