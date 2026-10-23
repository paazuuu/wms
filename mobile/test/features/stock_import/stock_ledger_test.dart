// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/html_sheet.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_ledger.dart';

final _now = DateTime(2026, 10, 23);

Uint8List _xlsxWithCreated(String created) {
  final a = Archive()
    ..addFile(ArchiveFile.string('docProps/core.xml',
        '<cp:coreProperties xmlns:dcterms="http://purl.org/dc/terms/"><dcterms:created xsi:type="dcterms:W3CDTF">$created</dcterms:created></cp:coreProperties>'));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

void main() {
  group('the date a file prints', () {
    test('in the ways documents write it', () {
      expect(dateIn('発行日 2026年8月19日', now: _now), DateTime(2026, 8, 19));
      expect(dateIn('2026/08/19', now: _now), DateTime(2026, 8, 19));
      expect(dateIn('入金希望日 2026-8-21', now: _now), DateTime(2026, 8, 21));
      expect(dateIn('令和8年8月19日', now: _now), DateTime(2026, 8, 19));
      expect(dateIn('R8.8.19', now: _now), DateTime(2026, 8, 19));
    });

    test('nothing that is not a date: an impossible day, far in the future, before 2000', () {
      expect(dateIn('2026/02/30', now: _now), isNull);
      expect(dateIn('2031/01/01', now: _now), isNull);
      expect(dateIn('1999/12/31', now: _now), isNull);
      expect(dateIn('JAN 4909999000014', now: _now), isNull);
    });

    test('a sheet: the cell that names the date wins over other dates; a serial number counts', () {
      final rows = [
        ['入金依頼書', '', '支払期限', '2026/09/30'],
        ['発行日', '', '2026/08/19'],
        ['JANコード', '数量'],
      ];
      expect(dateInRows(rows, now: _now), DateTime(2026, 8, 19));
      // Excel keeps 2026/08/19 as 46253.
      expect(dateInRows([
        ['作成日', '46253'],
      ], now: _now), DateTime(2026, 8, 19));
      // No label: the first date in the top rows.
      expect(dateInRows([
        ['', '2026/07/01'],
      ], now: _now), DateTime(2026, 7, 1));
    });

    test('the file’s own record: a PDF’s CreationDate, a workbook’s created', () {
      final pdf = Uint8List.fromList(latin1.encode('%PDF-1.4\n1 0 obj << /CreationDate (D:20260818093000+09\'00\') >>'));
      expect(fileCreated('a.pdf', pdf, now: _now), DateTime(2026, 8, 18));
      expect(fileCreated('a.xlsx', _xlsxWithCreated('2026-08-17T01:02:03Z'), now: _now), DateTime(2026, 8, 17));
      expect(fileCreated('a.png', Uint8List(10), now: _now), isNull);
    });

    test('the order: what the reader found, the sheet, the file’s own date, then today', () {
      final pdf = Uint8List.fromList(latin1.encode('/CreationDate (D:20260818)'));
      expect(findDocumentDate(fileName: 'a.pdf', bytes: pdf, readDate: '2026-08-19', now: _now),
          DocumentDate(DateTime(2026, 8, 19), DocumentDateSource.content));
      expect(findDocumentDate(fileName: 'a.pdf', bytes: pdf, now: _now),
          DocumentDate(DateTime(2026, 8, 18), DocumentDateSource.file));
      expect(
          findDocumentDate(fileName: 'a.csv', bytes: Uint8List(0), rows: [
            ['請求日', '2026/08/01']
          ], now: _now),
          DocumentDate(DateTime(2026, 8, 1), DocumentDateSource.content));
      expect(findDocumentDate(fileName: 'a.csv', bytes: Uint8List(0), rows: const [], readDate: 'not a date', now: _now),
          DocumentDate(DateTime(2026, 10, 23), DocumentDateSource.uploaded));
      expect(DocumentDate(DateTime(2026, 8, 9), DocumentDateSource.manual).wire, '2026-08-09');
    });
  });

  test('kept seven years from its date', () {
    expect(keptUntil(DateTime(2026, 8, 19)), DateTime(2033, 8, 18));
  });

  test('waiting units by warehouse and JAN, never mixed with another warehouse', () {
    final p = PendingInspection.fromRows([
      {'warehouse_id': 1, 'jan_code': '4909999000014', 'quantity': 500},
      {'warehouse_id': 2, 'jan_code': '4909999000014', 'quantity': 20},
      {'warehouse_id': 1, 'jan_code': '4909999000021', 'quantity': 3},
    ]);
    expect(p.of('4909999000014', warehouseId: 1), 500);
    expect(p.of('4909999000014', warehouseId: 2), 20);
    expect(p.of('4909999000014'), 520);
    expect(p.of('4909999000038'), 0);
    expect(const PendingInspection().isEmpty, isTrue);
  });

  test('the sheet page: column letters, row numbers, flagged cells, text escaped', () {
    final html = htmlSheet(
      title: '読み取り結果 <#12>',
      top: [
        ['ファイル', 'a&b.pdf'],
      ],
      headers: const ['行', 'JAN', '数量'],
      rows: const [
        [2, '4909999000014', '500'],
        [3, '', '<b>x</b>'],
      ],
      flagged: {(1, 1)},
    );
    expect(html, contains('<th>A</th><th>B</th><th>C</th>'));
    expect(html, contains('読み取り結果 &lt;#12&gt;'));
    expect(html, contains('a&amp;b.pdf'));
    expect(html, contains('&lt;b&gt;x&lt;/b&gt;'));
    expect(html, isNot(contains('<b>x</b>')));
    expect(html, contains('<td class="f"></td>'));
    expect(html, contains('<td class="num">2</td>'));
    // The JAN stays text, as written.
    expect(html, contains('<td>4909999000014</td>'));
    expect(html, contains('prefers-color-scheme: dark'));
  });
}
