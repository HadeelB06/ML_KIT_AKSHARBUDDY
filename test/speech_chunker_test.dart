import 'package:flutter_test/flutter_test.dart';
import 'package:aksharally_ui/services/speech_chunker.dart';

void main() {
  test('chunks keep original offsets and stay short', () {
    final text = List.filled(3000, 'word').join(' ');
    final chunks = buildSpeechChunks(text);
    expect(chunks.length, greaterThan(10));
    for (final c in chunks) {
      expect(c.spoken.length, c.end - c.start);
      expect(c.spoken.length, lessThanOrEqualTo(500));
    }
  });

  test('page markers are not spoken and wrapped lines are joined', () {
    const text = 'राजस्थान राज्य\nविधिक सेवा।\n\n—— Page 2 ——\nHello world.';
    final chunks = buildSpeechChunks(text);
    final spoken = chunks.map((c) => c.spoken).join(' ');
    expect(spoken.contains('Page'), isFalse);
    expect(spoken.contains('\n'), isFalse);
    expect(chunks.first.start, 0);
  });

  test('blank text produces no chunks', () {
    expect(buildSpeechChunks('  \n '), isEmpty);
  });

  test('exact limit and supplementary characters retain valid offsets', () {
    for (final text in [
      'x' * 500 + ' next',
      'x' * 499 + '\u{1F600}' + 'next',
    ]) {
      final chunks = buildSpeechChunks(text);
      expect(chunks.map((c) => c.spoken).join(), text);
      expect(chunks.every((c) => c.spoken.length <= 500), isTrue);
      expect(chunks.every((c) => !c.spoken.runes.contains(0xFFFD)), isTrue);
    }
  });
}
