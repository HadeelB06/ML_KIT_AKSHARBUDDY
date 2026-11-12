import 'dart:io';
import 'package:flutter/services.dart';
import 'docx_input_service.dart';
import '../models/ocr_document.dart';
import 'mlkit_ocr_service.dart';
import 'ocr/ocr_rules.dart';
import 'ocr_store.dart';

class DocumentSession {
  final String originalPath, kind;
  final String? token, text;
  final int pageCount;
  const DocumentSession({
    required this.originalPath,
    required this.kind,
    this.token,
    this.text,
    this.pageCount = 1,
  });
}

class InputCancellation {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

class DocumentInputService {
  static const _channel = MethodChannel('aksharbuddy/local_pdf');
  Future<DocumentSession> open(File original) async {
    if (original.path.toLowerCase().endsWith('.docx')) {
      return DocumentSession(
        originalPath: original.path,
        kind: 'docx',
        text: await DocxInputService.read(original.path),
      );
    }
    final data = await _channel.invokeMapMethod<String, dynamic>('open', {
      'path': original.path,
    });
    if (data == null) throw StateError('Could not open this PDF.');
    return DocumentSession(
      originalPath: original.path,
      kind: 'pdf',
      token: data['token'] as String,
      pageCount: data['pageCount'] as int,
    );
  }

  Future<void> close(DocumentSession session) async {
    if (session.token != null) {
      await _channel.invokeMethod<void>('close', {'token': session.token});
    }
  }

  Future<OcrDocument> read(
    DocumentSession session, {
    required String language,
    required int first,
    required int last,
    required InputCancellation cancellation,
    required void Function(String) progress,
    void Function(OcrPage)? onPage,
    bool importantNumbers = false,
  }) async {
    if (first < 1 || last < first || last > session.pageCount) {
      throw ArgumentError('Invalid page range.');
    }
    var document = OcrDocument(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      language: language,
      sourceType: session.kind,
      originalPath: session.originalPath,
      totalPages: session.pageCount,
      pages: [],
      importantNumbers: importantNumbers,
    );
    final pages = <OcrPage>[];
    try {
      for (var n = first; n <= last; n++) {
        if (cancellation.cancelled) break;
        progress('Page $n of ${session.pageCount}');
        OcrPage page;
        try {
          if (session.kind == 'docx') {
            page = OcrPage(
              rawOcrText: session.text!,
              language: language,
              sourceType: 'docx',
              originalPath: session.originalPath,
            );
          } else {
            final dir = await OcrStore.directory();
            final target = '${dir.path}/pdf_${document.id}_$n.png';
            var data = await _channel.invokeMapMethod<String, dynamic>(
              'page',
              {'token': session.token, 'page': n, 'target': target},
            );
            if (data == null) throw StateError('Page returned no result.');
            // Many Hindi/Marathi PDFs use legacy fonts (Kruti Dev etc.): the
            // text layer looks fine on screen but extracts as "Hkkjr ljdkj".
            // Such pages are rendered and OCR'd instead of read aloud as junk.
            if (data['kind'] == 'native' &&
                !pdfTextLooksUsable(data['text'] as String, language)) {
              progress('Page $n: re-reading the printed page');
              data = await _channel.invokeMapMethod<String, dynamic>('page', {
                'token': session.token,
                'page': n,
                'target': target,
                'forceImage': true,
              });
              if (data == null) throw StateError('Page returned no result.');
            }
            if (data['kind'] == 'native') {
              page = OcrPage(
                rawOcrText: data['text'] as String,
                language: language,
                sourceType: 'pdf-native',
                originalPath: session.originalPath,
                pageNumber: n,
              );
            } else {
              final file = File(data['path'] as String);
              page = await MlkitOcrService().recognize(
                path: file.path,
                language: language,
                sourceType: 'pdf-mlkit',
                originalPath: session.originalPath,
                pageNumber: n,
                importantNumbers: importantNumbers,
              );
            }
          }
        } catch (e) {
          page = OcrPage(
            rawOcrText: '',
            language: language,
            sourceType: session.kind,
            originalPath: session.originalPath,
            pageNumber: n,
            status: 'failed',
            error: e.toString(),
          );
        }
        pages.add(page);
        onPage?.call(page);
        document = document.withPages(pages);
        // Durable checkpoint after every page. A failed page cannot erase earlier pages.
        await OcrStore.save(document);
      }
      document = document.withPages(pages, cancelled: cancellation.cancelled);
      await OcrStore.save(document);
      return document;
    } finally {
      try {
        await close(session);
      } catch (_) {
        /* Results already saved. */
      }
    }
  }
}
