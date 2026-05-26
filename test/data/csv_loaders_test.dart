import 'package:flutter_test/flutter_test.dart';
import 'package:lexaway/data/csv_loaders.dart';

void main() {
  group('parseCsv', () {
    test('splits simple rows', () {
      final r = parseCsv('a,b,c\n1,2,3');
      expect(r, [
        ['a', 'b', 'c'],
        ['1', '2', '3'],
      ]);
    });

    test('handles quoted field with a comma', () {
      // The bug we just fixed: `"Benvenuto a casa, eh"` must not split.
      final r = parseCsv('it,"Benvenuto a casa, eh",any');
      expect(r, [
        ['it', 'Benvenuto a casa, eh', 'any'],
      ]);
    });

    test('handles escaped double-quote inside a quoted field', () {
      // RFC4180: `""` inside a quoted field is a literal `"`.
      final r = parseCsv('en,"She said ""hi""",morning');
      expect(r, [
        ['en', 'She said "hi"', 'morning'],
      ]);
    });

    test('handles CRLF line endings', () {
      final r = parseCsv('a,b\r\n1,2');
      expect(r, [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('strips UTF-8 BOM', () {
      final r = parseCsv('\uFEFFa,b\n1,2');
      expect(r.first.first, 'a');
    });

    test('drops empty trailing line', () {
      final r = parseCsv('a,b\n\n');
      expect(r.length, 1);
    });

    test('flushes final row with no trailing newline', () {
      final r = parseCsv('a,b');
      expect(r, [
        ['a', 'b']
      ]);
    });
  });

  group('timeBucketForHour', () {
    test('boundaries land in the expected bucket', () {
      expect(timeBucketForHour(4), 'night');
      expect(timeBucketForHour(5), 'morning');
      expect(timeBucketForHour(11), 'morning');
      expect(timeBucketForHour(12), 'afternoon');
      expect(timeBucketForHour(16), 'afternoon');
      expect(timeBucketForHour(17), 'evening');
      expect(timeBucketForHour(20), 'evening');
      expect(timeBucketForHour(21), 'night');
      expect(timeBucketForHour(0), 'night');
      expect(timeBucketForHour(23), 'night');
    });
  });
}
