import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aksharally_ui/services/document_input_service.dart';
import 'package:aksharally_ui/services/ocr_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  final requests = <int>[];
  var closed = false;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('buddy_coverage_');
    requests.clear();
    closed = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temp.path,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('aksharbuddy/local_pdf'),
          (call) async {
            if (call.method == 'close') {
              closed = true;
              return null;
            }
            final n = call.arguments['page'] as int;
            requests.add(n);
            if (n == 2) {
              throw PlatformException(
                code: 'PDF_INPUT',
                message: 'Damaged page',
              );
            }
            return {
              'kind': 'native',
              'text': 'Page $n: 17/10/2026 ₹250 शुभ दीपावली मराठी',
            };
          },
        );
  });
  tearDown(() => temp.deleteSync(recursive: true));
  test(
    'page failure remains explicit and subsequent pages are preserved',
    () async {
      final result = await DocumentInputService().read(
        const DocumentSession(
          originalPath: 'sample.pdf',
          kind: 'pdf',
          token: 'token',
          pageCount: 3,
        ),
        language: 'mr',
        first: 1,
        last: 3,
        cancellation: InputCancellation(),
        progress: (_) {},
      );
      expect(requests, [1, 2, 3]);
      expect(result.pages.map((p) => p.pageNumber), [1, 2, 3]);
      expect(result.pages[1].status, 'failed');
      expect(result.pages.last.rawOcrText, contains('₹250 शुभ दीपावली मराठी'));
      expect(closed, isTrue);
      final records = await OcrStore.records();
      final restored = await OcrStore.load(records.single.path);
      expect(restored.pages.length, 3);
      expect(restored.pages[1].error, contains('Damaged page'));
    },
  );
  test(
    'cancellation checkpoints processed pages without claiming full coverage',
    () async {
      final cancellation = InputCancellation();
      final result = await DocumentInputService().read(
        const DocumentSession(
          originalPath: 'sample.pdf',
          kind: 'pdf',
          token: 'token',
          pageCount: 91,
        ),
        language: 'hi',
        first: 1,
        last: 91,
        cancellation: cancellation,
        progress: (_) {},
        onPage: (_) => cancellation.cancel(),
      );
      expect(requests, [1]);
      expect(result.pages.length, 1);
      expect(result.totalPages, 91);
      expect(result.cancelled, isTrue);
      expect(closed, isTrue);
    },
  );
}
