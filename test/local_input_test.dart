import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aksharally_ui/models/ocr_document.dart';
import 'package:aksharally_ui/services/docx_input_service.dart';
import 'package:aksharally_ui/services/mlkit_ocr_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() {
  test(
    'editing and persistence preserve raw punctuation, spacing and errors',
    () {
      const raw = '  शुभ दीपावली\nDose 2.5 mg — 17/10/2026  ';
      final page = const OcrPage(
        rawOcrText: raw,
        language: 'hi',
        sourceType: 'pdf-native',
        pageNumber: 2,
      ).edited('User edit');
      final document = OcrDocument(
        id: '1',
        language: 'hi',
        sourceType: 'pdf',
        totalPages: 91,
        cancelled: true,
        pages: [
          page,
          const OcrPage(
            rawOcrText: '',
            language: 'hi',
            sourceType: 'pdf',
            pageNumber: 3,
            status: 'failed',
            error: 'Unreadable',
          ),
        ],
      );
      final restored = OcrDocument.fromJson(
        jsonDecode(jsonEncode(document.toJson())),
      );
      expect(restored.pages.first.rawOcrText, raw);
      expect(restored.pages.first.displayText, 'User edit');
      expect(restored.pages.last.error, 'Unreadable');
      expect(restored.totalPages, 91);
      expect(restored.cancelled, isTrue);
      expect(() => restored.pages.clear(), throwsUnsupportedError);
    },
  );
  test('explicit language maps to bundled script without guessing', () {
    expect(MlkitOcrService.scriptFor('en'), TextRecognitionScript.latin);
    expect(MlkitOcrService.scriptFor('hi'), TextRecognitionScript.devanagiri);
    expect(MlkitOcrService.scriptFor('mr'), TextRecognitionScript.devanagiri);
    expect(() => MlkitOcrService.scriptFor('auto'), throwsArgumentError);
  });
  test(
    'DOCX preserves paragraph, table, content control and whitespace order',
    () {
      final xml = utf8.encode(
        '''<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
<w:p><w:r><w:t xml:space="preserve">  शुभ दीपावली  </w:t><w:tab/><w:t>17</w:t><w:br/><w:t>Next</w:t></w:r></w:p>
<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Name</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>२.५</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
<w:sdt><w:sdtContent><w:p><w:r><w:t>मराठी</w:t></w:r></w:p></w:sdtContent></w:sdt>
</w:body></w:document>''',
      );
      final zip = Archive()
        ..addFile(ArchiveFile('word/document.xml', xml.length, xml));
      expect(
        extractDocxBytes(ZipEncoder().encode(zip)),
        '  शुभ दीपावली  \t17\nNext\nName\t२.५\nमराठी',
      );
    },
  );
}
