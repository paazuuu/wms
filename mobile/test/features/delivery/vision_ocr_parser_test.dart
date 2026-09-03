import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/domain/vision_ocr_parser.dart';

void main() {
  test('parses lines with product name and quantity from the data envelope', () {
    final json = {
      'data': {
        'provider': 'gemini',
        'lines': [
          {
            'jan_code': '4902505632037',
            'product_name': 'パイロット サインペン',
            'quantity': 100,
          },
          {'jan_code': '4901480241418', 'product_name': 'ホッチキス', 'quantity': 20},
        ],
      },
    };
    final result = parseVisionOcrResponse(json);
    expect(result.length, 2);
    expect(result.first.janCode, '4902505632037');
    expect(result.first.quantityHint, 100);
    expect(result.first.productName, 'パイロット サインペン');
  });

  test('accepts a bare lines array and coerces string quantities', () {
    final json = {
      'lines': [
        {'jan_code': '4902505632037', 'quantity': '100'},
      ],
    };
    final result = parseVisionOcrResponse(json);
    expect(result.single.quantityHint, 100);
  });

  test('drops entries whose JAN fails validation', () {
    final json = {
      'lines': [
        {'jan_code': '3122001027817'}, // registration number, bad checksum
        {'jan_code': 'not-a-code'},
        {'jan_code': '4902505632037'}, // valid
      ],
    };
    final result = parseVisionOcrResponse(json);
    expect(result.map((e) => e.janCode), ['4902505632037']);
  });

  test('accepts JAN-8 codes', () {
    final json = {
      'lines': [
        {'jan_code': '49025058', 'quantity': 2},
      ],
    };
    final result = parseVisionOcrResponse(json);
    expect(result.single.janCode, '49025058');
  });

  test('collapses duplicate JANs and tolerates a missing lines key', () {
    expect(parseVisionOcrResponse({'data': {}}), isEmpty);
    final dup = parseVisionOcrResponse({
      'lines': [
        {'jan_code': '4902505632037', 'quantity': 1},
        {'jan_code': '4902505632037', 'quantity': 9},
      ],
    });
    expect(dup.length, 1);
    expect(dup.single.quantityHint, 1);
  });
}
