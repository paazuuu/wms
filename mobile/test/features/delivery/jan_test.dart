import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/domain/jan.dart';

void main() {
  group('normalizeJan', () {
    test('passes a clean 13-digit JAN through unchanged', () {
      expect(normalizeJan('4902505632037'), '4902505632037');
    });

    test('strips hyphens and spaces', () {
      expect(normalizeJan('4902-5056-32037'), '4902505632037');
      expect(normalizeJan(' 49025 05632037 '), '4902505632037');
    });

    test('converts full-width digits to half-width', () {
      expect(normalizeJan('４９０２５０５６３２０３７'), '4902505632037');
    });

    test('handles mixed full/half-width and hyphens together', () {
      expect(normalizeJan('４９０2-505-632037'), '4902505632037');
    });

    test('drops an Excel trailing .0 (number-formatted cell)', () {
      expect(normalizeJan('4902505632037.0'), '4902505632037');
      expect(normalizeJan('4902506327734.00'), '4902506327734');
    });

    test('left-pads a 12-digit code to 13 (lost leading zero / UPC-A)', () {
      expect(normalizeJan('490250563203'), '0490250563203');
    });

    test('removes stray letters and symbols', () {
      expect(normalizeJan('JAN:4902505632037*'), '4902505632037');
    });

    test('empty / non-numeric input yields empty string', () {
      expect(normalizeJan(''), '');
      expect(normalizeJan('N/A'), '');
    });
  });
}
