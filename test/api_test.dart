import 'package:flutter_test/flutter_test.dart';
import 'package:aksharally_ui/services/api_service.dart';
void main() {
  test('original-only ML Kit build does not send passages for simplification', () async {
    for (final language in ['en', 'hi', 'mr']) {
      await expectLater(ApiService.simplifyText('Original text', language: language), throwsUnsupportedError);
      await expectLater(ApiService.simplifyStructuredText('Original text', {'blocks': []}, language: language), throwsUnsupportedError);
    }
  });
}
