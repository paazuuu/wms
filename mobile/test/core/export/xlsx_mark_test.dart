import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/xlsx.dart';

void main() {
  test('rows marked red with the reason at the right; values, formulas and other sheets kept', () {
    final book = buildXlsxBook([
      const XlsxSheet(name: '明细', headers: ['JAN', '数量', '単価', '合計'], rows: [
        ['4909999000014', 10, 5, XlsxFormula('B2*C2', cached: 50)],
        ['', 3, 5, XlsxFormula('B3*C3', cached: 15)],
      ], flagged: {(0, 1)}),
      const XlsxSheet(name: 'memo', headers: ['a'], rows: [
        ['b'],
      ]),
    ]);
    final marked = markXlsxRows(book, {2: 'JANがありません'}, headerRow: 0, noteHeading: '理由');
    final sheets = readXlsxSheets(marked);
    expect(sheets.map((s) => s.name), ['明细', 'memo']);
    expect(sheets.first.rows, [
      ['JAN', '数量', '単価', '合計', '理由'],
      ['4909999000014', '10', '5', '50'],
      ['', '3', '5', '15', 'JANがありません'],
    ]);
    final zip = ZipDecoder().decodeBytes(marked);
    String file(String n) => utf8.decode(zip.findFile(n)!.content as List<int>);
    final sheet = file('xl/worksheets/sheet1.xml');
    expect(sheet, contains('<f>B3*C3</f>'));
    final styles = file('xl/styles.xml');
    expect(styles, contains('FFFFC7CE'));
    expect(styles, contains('<fills count="5">'));
    // The marked row's cells point at a copy of their format with the red fill.
    final row3 = RegExp(r'<row r="3"[^>]*>(.*?)</row>').firstMatch(sheet)!.group(1)!;
    final ids = RegExp(r' s="(\d+)"').allMatches(row3).map((m) => int.parse(m.group(1)!)).toSet();
    expect(ids.every((i) => i >= 4), isTrue, reason: 'new formats after the 4 the book had');
    expect(RegExp(r'<row r="2"[^>]*>(.*?)</row>').firstMatch(sheet)!.group(1), contains('s="2"'), reason: 'unmarked rows as they were');
    expect(() => markXlsxRows(utf8.encode('not a zip'), {0: 'x'}), throwsFormatException);
  });
}
