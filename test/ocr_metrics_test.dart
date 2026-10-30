import 'package:flutter_test/flutter_test.dart';
import 'package:aksharally_ui/services/ocr_metrics.dart';

void main() {
  test('CER/WER basics', () {
    expect(cer('abcd', 'abcd'), 0);
    expect(cer('abcd', 'abXd'), 0.25);
    expect(wer('a b c d', 'a b c'), 0.25);
    expect(cer('गंध', 'गध'), closeTo(1 / 3, 1e-9));
  });
}
