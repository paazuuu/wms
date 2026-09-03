import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_note_parser.dart';

void main() {
  group('isValidEan13', () {
    test('accepts a real JAN with a correct check digit', () {
      // 4902505632037 is a valid EAN-13 (from the sample delivery note).
      expect(isValidEan13('4902505632037'), isTrue);
    });

    test('rejects a 13-digit number with a wrong check digit', () {
      expect(isValidEan13('4902505632030'), isFalse);
    });

    test('rejects the tax registration number digits (not a JAN)', () {
      // "T3122001027817" -> the 13 digits fail the EAN-13 checksum.
      expect(isValidEan13('3122001027817'), isFalse);
    });

    test('rejects wrong length or non-digits', () {
      expect(isValidEan13('490250563203'), isFalse);
      expect(isValidEan13('49025056320370'), isFalse);
      expect(isValidEan13('49025056320A7'), isFalse);
    });
  });

  group('parseDeliveryNoteText', () {
    test('extracts valid JANs and ignores other 13-digit numbers', () {
      final lines = [
        'T3122001027817 登録番号', // registration — not a JAN
        '4902505632037 30232955 パイロット BP05 880 100 440 44000',
        '4901480241418 HSM-500TM-D 1650 20 729 14580',
      ];
      final result = parseDeliveryNoteText(lines);
      expect(result.map((e) => e.janCode),
          ['4902505632037', '4901480241418']);
      expect(result.first.rawText, contains('パイロット'));
    });

    test('collapses duplicate JANs, keeping the first occurrence', () {
      final lines = [
        '4902505632037 first',
        '4902505632037 second',
      ];
      final result = parseDeliveryNoteText(lines);
      expect(result.length, 1);
      expect(result.single.rawText, contains('first'));
    });

    test('does not grab a JAN embedded in a longer digit run', () {
      final result = parseDeliveryNoteText(['990490250563203712345']);
      expect(result, isEmpty);
    });

    test('returns empty for text with no codes', () {
      expect(parseDeliveryNoteText(['納品書', '数量 単価 金額']), isEmpty);
    });
  });
}
