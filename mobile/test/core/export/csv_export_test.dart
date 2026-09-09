import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/csv_export.dart';

void main() {
  String decode(List<int> bytes) {
    // Strip the leading UTF-8 BOM before comparing text.
    const bom = [0xEF, 0xBB, 0xBF];
    final body = bytes.sublist(bom.length);
    return utf8.decode(body);
  }

  test('renders headers and rows as comma-separated lines', () {
    final bytes = csvBytes(
      headers: const ['JAN', '数量'],
      rows: const [
        ['4901234567894', 20],
        ['4901234567895', -3],
      ],
    );
    expect(decode(bytes), 'JAN,数量\n4901234567894,20\n4901234567895,-3\n');
  });

  test('quotes a field that contains a comma', () {
    final bytes = csvBytes(
      headers: const ['note'],
      rows: const [
        ['damaged, replaced'],
      ],
    );
    expect(decode(bytes), 'note\n"damaged, replaced"\n');
  });

  test('doubles an embedded quote per RFC 4180', () {
    final bytes = csvBytes(
      headers: const ['note'],
      rows: const [
        ['a "special" note'],
      ],
    );
    expect(decode(bytes), 'note\n"a ""special"" note"\n');
  });

  test('quotes a field that contains a newline', () {
    final bytes = csvBytes(
      headers: const ['note'],
      rows: const [
        ['line one\nline two'],
      ],
    );
    expect(decode(bytes), 'note\n"line one\nline two"\n');
  });

  test('a null cell renders as an empty field, not the string "null"', () {
    final bytes = csvBytes(
      headers: const ['a', 'b'],
      rows: const [
        [null, 1],
      ],
    );
    expect(decode(bytes), 'a,b\n,1\n');
  });

  test('prepends a UTF-8 BOM so Excel reads Japanese text correctly', () {
    final bytes = csvBytes(headers: const ['商品名'], rows: const []);
    expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
  });
}
