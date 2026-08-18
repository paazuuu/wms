import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/scan/scan_buffer.dart';

void main() {
  group('ScanBuffer', () {
    late ScanBuffer buffer;
    late DateTime t;

    setUp(() {
      buffer = ScanBuffer(
        interKeyTimeout: const Duration(milliseconds: 120),
        minLength: 2,
      );
      t = DateTime(2026, 1, 1, 12, 0, 0);
    });

    DateTime plusMs(int ms) => t.add(Duration(milliseconds: ms));

    test('captures a fast keystroke burst ended by a terminator', () {
      const code = '4901234567894';
      var offset = 0;
      for (final ch in code.split('')) {
        offset += 15; // 15ms/key — scanner speed
        buffer.feed(ch, plusMs(offset));
      }
      final result = buffer.flush(plusMs(offset + 10));
      expect(result, code);
    });

    test('resets the burst when a slow gap breaks it', () {
      buffer.feed('A', plusMs(0));
      buffer.feed('B', plusMs(20));
      // Long pause: a new burst starts, discarding "AB".
      buffer.feed('C', plusMs(500));
      buffer.feed('D', plusMs(515));
      expect(buffer.flush(plusMs(525)), 'CD');
    });

    test('rejects a terminator that arrives long after the last key', () {
      buffer.feed('9', plusMs(0));
      buffer.feed('9', plusMs(15));
      // Human pressed Enter much later — not a scan.
      expect(buffer.flush(plusMs(800)), isNull);
    });

    test('rejects a burst shorter than minLength', () {
      buffer.feed('7', plusMs(0));
      expect(buffer.flush(plusMs(10)), isNull);
    });

    test('flush with no input returns null', () {
      expect(buffer.flush(plusMs(0)), isNull);
    });

    test('reset clears an in-progress burst', () {
      buffer.feed('1', plusMs(0));
      buffer.feed('2', plusMs(15));
      buffer.reset();
      expect(buffer.length, 0);
      buffer.feed('3', plusMs(30));
      buffer.feed('4', plusMs(45));
      expect(buffer.flush(plusMs(55)), '34');
    });
  });
}
