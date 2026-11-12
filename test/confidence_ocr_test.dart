import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:aksharally_ui/services/ocr/ocr_rules.dart';
import 'package:aksharally_ui/services/ocr/reading_order.dart';

void main() {
  const c = OcrRuleConfig();

  group('suspicious words', () {
    test('broken matra at word start', () {
      expect(wordReasons('िकताब', null, c), contains(Reason.brokenMatra));
      expect(wordReasons('किताब', null, c), isEmpty);
      expect(wordReasons('पढ़ाई', null, c), isEmpty);
    });
    test('Devanagari and Latin mixed in one word', () {
      expect(wordReasons('कiताब', null, c), contains(Reason.mixedScript));
      expect(wordReasons('Paneer', null, c), isEmpty);
    });
    test('digit / letter confusion, but not real units', () {
      expect(wordReasons('1O5', null, c), contains(Reason.digitLetterMix));
      expect(wordReasons('S00', null, c), contains(Reason.digitLetterMix));
      for (final ok in ['10am', '2nd', '5kg', '50ml', 'COVID-19', '₹250', 'A4']) {
        expect(wordReasons(ok, null, c), isEmpty, reason: ok);
      }
    });
    test('mixed digit systems', () {
      expect(wordReasons('१2३', null, c), contains(Reason.mixedDigits));
      expect(wordReasons('१२३', null, c), isEmpty);
    });
    test('low confidence only when ML Kit reports one', () {
      expect(wordReasons('hello', 0.2, c), contains(Reason.lowConfidence));
      expect(wordReasons('hello', null, c), isEmpty);
    });
  });

  group('numbers, times, dates', () {
    test('impossible or ambiguous times are flagged', () {
      expect(lineReasons('The exam starts at 10530 AM.'), contains(Reason.badTime));
      expect(lineReasons('Shop closes 25:10'), contains(Reason.badTime));
      expect(lineReasons('Price 1030 PM'), contains(Reason.badTime));
    });
    test('valid times pass, including Devanagari digits', () {
      expect(lineReasons('The exam starts at 10:30 AM.'), isEmpty);
      expect(lineReasons('at 10 am'), isEmpty);
      expect(lineReasons('१०:३० am'), isEmpty);
      expect(lineReasons('Call 9876543210 am'), isEmpty);
    });
    test('dates', () {
      expect(lineReasons('Date 17/10/2026'), isEmpty);
      expect(lineReasons('Date 37/10/2026'), contains(Reason.badDate));
      expect(lineReasons('Date 17/13/2026'), contains(Reason.badDate));
    });
  });

  group('consensus: never silently change an uncertain number', () {
    test('suspicious time with agreeing retries -> needs check + suggestion', () {
      final d = decide('The exam starts at 10530 AM.', [
        'The exam starts at 10:30 AM.',
        'The exam starts at 10:30 AM.',
      ]);
      expect(d.status, LineStatus.needsCheck);
      expect(d.text, 'The exam starts at 10530 AM.');
      expect(d.suggestion, 'The exam starts at 10:30 AM.');
    });
    test('same, with important-numbers off -> verified correction', () {
      final d = decide('The exam starts at 10530 AM.', [
        'The exam starts at 10:30 AM.',
        'The exam starts at 10:30 AM.',
      ], strictNumbers: false);
      expect(d.status, LineStatus.corrected);
      expect(d.text, 'The exam starts at 10:30 AM.');
    });
    test('retries keep reading the same bad value -> highlighted, unchanged', () {
      final d = decide('at 10530 AM', ['at 10530 AM', 'at 10530 AM']);
      expect(d.status, LineStatus.needsCheck);
      expect(d.suggestion, isNull);
    });
    test('broken matra fixed by two agreeing re-reads -> corrected', () {
      final d = decide('िकताब पढ़ो', ['किताब पढ़ो', 'किताब पढ़ो']);
      expect(d.status, LineStatus.corrected);
      expect(d.text, 'किताब पढ़ो');
    });
    test('original confirmed by a re-read -> verified, no warning', () {
      final d = decide('Paneer Tikka', ['Paneer Tlkka', 'Paneer Tikka']);
      expect(d.status, LineStatus.verified);
    });
    test('no agreement -> needs check', () {
      final d = decide('Paneer Tlkka', ['Paneer Tikka', 'Paneer Tikko']);
      expect(d.status, LineStatus.needsCheck);
      expect(d.text, 'Paneer Tlkka');
    });
  });

  group('PDF text layer validation', () {
    test('legacy Kruti Dev / broken font text is rejected', () {
      expect(pdfTextLooksUsable('Hkkjr ljdkj dh ;kstuk', 'hi'), isFalse);
      expect(pdfTextLooksUsable('ºÉÚSÉxÉÉ ¨ÉÆjÉɱɪÉ', 'hi'), isFalse);
      expect(pdfTextLooksUsable('ि कताब ि दन ि मलना ि कसान पढ़ाई', 'hi'), isFalse);
    });
    test('real Unicode Hindi / Marathi / English is accepted', () {
      expect(pdfTextLooksUsable('भारत सरकार की योजना के तहत सभी छात्रों को', 'hi'), isTrue);
      expect(pdfTextLooksUsable('Page 1: 17/10/2026 ₹250 शुभ दीपावली मराठी', 'mr'), isTrue);
      expect(pdfTextLooksUsable('Chapter 3 पाठ ३ Science विज्ञान', 'hi'), isTrue);
      expect(pdfTextLooksUsable('The quick brown fox, café', 'en'), isTrue);
    });
  });

  group('reading order', () {
    test('two columns are read one after the other, headline first', () {
      final texts = [
        'Big school news headline today',
        'left column first line of text',
        'left column second line of text',
        'left column third line of text',
        'right column first line of text',
        'right column second line of text',
        'right column third line of text',
      ];
      final boxes = [
        const OcrBox(0, 0, 400, 30),
        const OcrBox(0, 60, 180, 80),
        const OcrBox(0, 90, 180, 110),
        const OcrBox(0, 120, 180, 140),
        const OcrBox(220, 60, 400, 80),
        const OcrBox(220, 90, 400, 110),
        const OcrBox(220, 120, 400, 140),
      ];
      final o = orderLines(texts, boxes);
      expect(o.tableLike, isFalse);
      final flat = [for (final g in o.groups) ...g].map((i) => texts[i]).toList();
      expect(flat, texts); // headline, whole left column, then right column
    });
    test('menus keep item and price on the same row', () {
      final texts = ['Paneer Tikka', '₹250', 'Dal Makhani', '₹180', 'पनीर', '₹90', 'Naan', '₹40'];
      final boxes = [
        const OcrBox(0, 0, 150, 20), const OcrBox(300, 0, 350, 20),
        const OcrBox(0, 40, 150, 60), const OcrBox(300, 40, 350, 60),
        const OcrBox(0, 80, 80, 100), const OcrBox(300, 80, 340, 100),
        const OcrBox(0, 120, 60, 140), const OcrBox(300, 120, 340, 140),
      ];
      final o = orderLines(texts, boxes);
      expect(o.tableLike, isTrue);
      expect(o.groups.first.map((i) => texts[i]), ['Paneer Tikka', '₹250']);
    });
  });

  group('Devanagari full stop', () {
    test('bar after a Hindi word becomes a danda', () {
      expect(normalizeDanda('यह मेरा घर है|'), 'यह मेरा घर है।');
      expect(normalizeDanda('राम घर गया | सीता आई'), 'राम घर गया । सीता आई');
      expect(normalizeDanda('श्लोक समाप्त ||'), 'श्लोक समाप्त ॥');
    });
    test('English and code-like bars are left alone', () {
      expect(normalizeDanda('Name | Price'), 'Name | Price');
      expect(normalizeDanda('a|b'), 'a|b');
      expect(normalizeDanda('पनीर|tikka'), 'पनीर|tikka');
    });
  });

  group('tilted and sideways photos keep reading order', () {
    // Upright two-column page with a headline.
    final texts = [
      'Headline across the page',
      'left column first line',
      'left column second line',
      'left column third line',
      'right column first line',
      'right column second line',
      'right column third line',
    ];
    const upright = [
      OcrBox(0, 0, 400, 30),
      OcrBox(0, 60, 180, 80),
      OcrBox(0, 90, 180, 110),
      OcrBox(0, 120, 180, 140),
      OcrBox(220, 60, 400, 80),
      OcrBox(220, 90, 400, 110),
      OcrBox(220, 120, 400, 140),
    ];

    // Simulates ML Kit output for the page rotated by [deg]: corner points in
    // text order and upright bounding boxes around them.
    (List<OcrBox>, List<List<List<num>>>) photo(double deg) {
      final r = deg * math.pi / 180;
      List<num> rot(double x, double y) => [
        x * math.cos(r) - y * math.sin(r) + 1000,
        x * math.sin(r) + y * math.cos(r) + 1000,
      ];
      final boxes = <OcrBox>[];
      final corners = <List<List<num>>>[];
      for (final b in upright) {
        final c = [
          rot(b.left, b.top),
          rot(b.right, b.top),
          rot(b.right, b.bottom),
          rot(b.left, b.bottom),
        ];
        corners.add(c);
        final xs = c.map((p) => p[0].toDouble());
        final ys = c.map((p) => p[1].toDouble());
        boxes.add(OcrBox(xs.reduce(math.min), ys.reduce(math.min),
            xs.reduce(math.max), ys.reduce(math.max)));
      }
      return (boxes, corners);
    }

    for (final deg in [0.0, 6.0, -9.0, 90.0, -90.0, 180.0]) {
      test('page rotated by $deg degrees (corner points)', () {
        final (boxes, corners) = photo(deg);
        final o = orderLines(texts, deskewBoxes(boxes, corners));
        final flat = [for (final g in o.groups) ...g].map((i) => texts[i]).toList();
        expect(flat, texts);
      });
      test('page rotated by $deg degrees (ML Kit angles)', () {
        final (boxes, corners) = photo(deg);
        final o = orderLines(
          texts,
          deskewBoxes(boxes, corners, angles: List.filled(boxes.length, deg)),
        );
        final flat = [for (final g in o.groups) ...g].map((i) => texts[i]).toList();
        expect(flat, texts);
      });
    }

    test('small tilt below the threshold changes nothing', () {
      final (boxes, corners) = photo(0.5);
      expect(identical(deskewBoxes(boxes, corners), boxes), isTrue);
    });
  });

  group('numbers are never changed silently', () {
    test('even when two re-reads agree on a different number', () {
      final d = decide('Take 1O5 mg', ['Take 105 mg', 'Take 105 mg']);
      expect(d.status, LineStatus.needsCheck);
      expect(d.text, 'Take 1O5 mg');
      expect(d.suggestion, 'Take 105 mg');
    });
  });
}
