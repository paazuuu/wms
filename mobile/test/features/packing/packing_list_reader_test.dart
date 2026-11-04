import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/packing/data/packing_list_excel.dart';
import 'package:wms_mobile/features/packing/domain/packing.dart';
import 'package:wms_mobile/features/packing/domain/packing_list_reader.dart';
import 'package:wms_mobile/features/shipment/domain/packaging.dart';

/// A packing list laid out the way suppliers send them: a box number on the
/// first row of each box, its size and weight once, more rows under it.
final _book = buildXlsxBook([
  const XlsxSheet(name: '明细', headers: ['品番', 'ジャパンコード', '数量', '単価', '注番'], rows: [
    ['X-1', '4909999000014', 60, 100, 'HL 1'],
    ['N-1', '4909999000021', 30, 100, 'BL 1'],
  ]),
  const XlsxSheet(name: 'PL-HL', headers: ['箱番号', '箱量', '品名', 'メーカー', '品番', '数量', 'サイズ', '单箱重量（kg）', '分重量'], rows: [
    [1, 1, 'Pen', 'MAKER A', 'X-1', 60, '54*38.5*34.5', 14.4],
    [2, 1, 'Pen', 'MAKER A', 'X-2', 40, '59.5 × 39 × 36', 14.6],
    [null, null, 'Pen', null, 'X-3', 20],
    ['3-4', 2, 'Clip', 'MAKER B', 'Y-1', 400, '31*29.5*17.5', 5],
    [5],
    ['合计', null, null, null, null, 520],
  ]),
  const XlsxSheet(name: 'Sheet4', headers: ['箱番号', '箱量', '品名', '品番', '数量', 'サイズ', '单箱重量（kg）', '按数量分重量（kg）', '', '品名汇总', '数量合计'], rows: [
    [1, 1, 'Note', 'N-1', 30, '40*30*20', 3.2, 3.2, null, 'Note', 30],
    [2, null, 'Note', 'N-2', 10, '40x30x20cm', null, 1.1, null, '总计', 30],
    [null, null, 'Note', 'N-3', 10, null, null, 1.0],
  ]),
]);

void main() {
  test('headings in Japanese, Chinese and English', () {
    expect(guessPlField('箱番号'), PlField.cartonNo);
    expect(guessPlField('C/No.'), PlField.cartonNo);
    expect(guessPlField('箱量'), PlField.cartonCount);
    expect(guessPlField('单箱重量（kg）'), PlField.cartonWeight);
    expect(guessPlField('G.W. (kg)'), PlField.cartonWeight);
    expect(guessPlField('按数量分重量（kg）'), PlField.netWeight);
    expect(guessPlField('Measurement (cm)'), PlField.size);
    expect(guessPlField('Description of Goods'), PlField.description);
    expect(guessPlField('Item No.'), PlField.itemCode);
    expect(guessPlField('品名汇总'), isNull);
    expect(guessPlField('数量合计'), isNull);
    expect(plMarkOfSheet('PL-HL'), 'HL');
    expect(plMarkOfSheet('Sheet4'), '');
    expect(plMarkOfSheet('Packing List BL'), 'BL');
    expect(parsePlSize('36 × 32 × 30'), (36.0, 32.0, 30.0));
    expect(parsePlSize('５４＊３８.５＊３４.５'), (54.0, 38.5, 34.5));
    expect(parsePlSize('360x320x300mm'), (36.0, 32.0, 30.0));
    expect(parsePlSize('36'), isNull);
  });

  test('reads boxes: continuation rows, 箱量 and ranges, totals and empty numbers passed over', () async {
    final r = await readPackingList(_book);
    expect(r.sheets.map((s) => s.name), ['PL-HL', 'Sheet4']);
    final hl = r.boxes.where((b) => b.mark == 'HL').toList();
    expect(hl.map((b) => b.boxNo), [1, 2, 3, 4]);
    expect(hl[1].items.map((i) => i.code), ['X-2', 'X-3']);
    expect(hl[0].items.single.jan, '4909999000014', reason: 'from the 明细 sheet');
    expect(hl[1].items.first.jan, isNull);
    expect(hl[1].sizeText, '59.5 × 39 × 36');
    expect(hl[1].grossKg, 14.6);
    expect(hl[2].items.single.quantity, 400);
    expect(hl[3].items.single.quantity, 400, reason: '箱量 2: two boxes alike');
    final s4 = r.boxes.where((b) => b.mark == null).toList();
    expect(s4.map((b) => b.boxNo), [1, 2]);
    expect(s4[1].items, hasLength(2));
    expect(s4[1].grossKg, 2.1, reason: 'no box weight: the parts added up');
    expect(s4[1].lengthCm, 40);
    expect(r.quantity, 60 + 60 + 800 + 50);
    expect(r.marked, isTrue);
  });

  test('asks the AI only about a sheet that looks like a packing list but does not read', () async {
    final book = buildXlsxBook([
      const XlsxSheet(name: 'パッキング', headers: ['甲', '乙', '丙'], rows: [
        ['1', 'Z-1', '12'],
        ['2', 'Z-2', '6'],
      ]),
      const XlsxSheet(name: 'memo', headers: ['甲', '乙'], rows: [
        ['a', 'b'],
      ]),
    ]);
    final asked = <List<String>>[];
    final r = await readPackingList(book, ask: (h, s) async {
      asked.add(h);
      expect(s, hasLength(2));
      return {0: PlField.cartonNo, 1: PlField.itemCode, 2: PlField.quantity};
    });
    expect(asked, [
      ['甲', '乙', '丙'],
    ]);
    expect(r.askedAi, ['パッキング']);
    expect(r.boxes.map((b) => b.items.single.quantity), [12, 6]);
  });

  test('the improved list reads back as the same boxes, with its formulas and the box-type list', () async {
    final read = await readPackingList(_book);
    final bytes = buildPackingListXlsx(read.boxes,
        header: const PlHeader(consignee: 'ACME LTD'),
        cartons: const [CartonType(id: 1, name: 'M', lengthCm: 40, widthCm: 30, heightCm: 20)]);
    final sheets = readXlsxSheets(bytes);
    expect(sheets.map((s) => s.name), ['PACKING LIST', 'BOXES', 'BOX_TYPES', 'SUMMARY'], reason: 'no 明細 given');
    final types = sheets[2].rows.skip(1).map((r) => r.first).toList();
    expect(types, ['T1', 'T2', 'T3', 'M']);
    final back = await readPackingList(bytes);
    expect(back.boxes.map((b) => b.label), read.boxes.map((b) => b.label));
    expect(back.boxes.map((b) => b.quantity), read.boxes.map((b) => b.quantity));
    expect(back.boxes.map((b) => b.grossKg), read.boxes.map((b) => b.grossKg));
    expect(back.boxes.map((b) => b.sizeText.replaceAll(' x ', ' × ')), read.boxes.map((b) => b.sizeText));
    final zip = ZipDecoder().decodeBytes(bytes);
    final boxesXml = utf8.decode(zip.findFile('xl/worksheets/sheet2.xml')!.content as List<int>);
    expect(boxesXml, contains('<dataValidation type="list"'));
    expect(boxesXml, contains('BOX_TYPES!\$A\$2:\$A\$5'));
    final listXml = utf8.decode(zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
    expect(listXml, contains('VLOOKUP(\$A12,BOXES!\$A:\$I,2,FALSE)'));
    expect(listXml, contains('ACME LTD'));
    // Rows without a JAN are filled yellow.
    expect(RegExp(r'<c r="E\d+" s="2"').allMatches(listXml).length,
        read.boxes.fold(0, (a, b) => a + b.items.where((i) => i.jan == null).length));
  });

  test('the 明細 beside the packing list goes in too, and SUMMARY checks the boxes against it', () async {
    final read = await readPackingList(_book);
    expect(read.detailSheet, '明细');
    expect(read.detail.map((r) => r.code), ['X-1', 'N-1']);
    final bytes = buildPackingListXlsx(read.boxes, detail: [for (final r in read.detail) PlDetailRow.fromSheet(r)]);
    final sheets = readXlsxSheets(bytes);
    expect(sheets.map((s) => s.name), ['PACKING LIST', '明細', 'BOXES', 'BOX_TYPES', 'SUMMARY']);
    final detail = sheets[1].rows;
    expect(detail.first, contains('ジャパンコード'));
    expect(detail[1].sublist(5, 8), ['X-1', '4909999000014', '60']);
    expect(detail[1][11], '6600', reason: '合计 = 数量 × 単価（税込）');
    expect(detail.last.sublist(6, 8), ['合计', '90']);

    final summary = {for (final r in sheets[4].rows.skip(1)) r.first: r};
    expect(sheets[4].rows.first.sublist(5), ['明細の数量', '差（箱 − 明細）']);
    expect(summary['X-1']!.sublist(3), ['60', '1', '60', '0']);
    expect(summary['N-1']!.sublist(3), ['30', '1', '30', '0']);
    expect(summary['X-2']!.sublist(3), ['40', '1', '0', '40'], reason: 'not in the 明細');
    final zip = ZipDecoder().decodeBytes(bytes);
    final summaryXml = utf8.decode(zip.findFile('xl/worksheets/sheet5.xml')!.content as List<int>);
    expect(summaryXml, contains("SUMIF('明細'!\$F:\$F,A"));
    // Read back, the 明細 is the improved file's own and gives the same boxes.
    final back = await readPackingList(bytes);
    expect(back.detailSheet, '明細');
    expect(back.boxes.map((b) => b.quantity), read.boxes.map((b) => b.quantity));
  });

  test('learns case quantities from boxes of one product', () async {
    const boxes = [
      PackBox(boxNo: 1, lengthCm: 36, widthCm: 32, heightCm: 30, grossKg: 11.5, items: [PackItem(code: 'JJ', maker: 'Z', quantity: 1000)]),
      PackBox(boxNo: 2, lengthCm: 36, widthCm: 32, heightCm: 30, grossKg: 11.5, items: [PackItem(code: 'JJ', maker: 'Z', quantity: 1000)]),
      PackBox(boxNo: 3, items: [PackItem(code: 'JJ', maker: 'Z', quantity: 200)]),
      PackBox(boxNo: 4, items: [PackItem(code: 'A', quantity: 1), PackItem(code: 'B', quantity: 1)]),
    ];
    final l = learnCasePacks(boxes);
    expect(l, hasLength(1));
    expect(l.single.quantity, 1000);
    expect(l.single.kg, 11.5);
    expect(l.single.l, 36);
  });

  test('the page shows each box once with its rows', () {
    final html = packingListHtml(const [
      PackBox(boxNo: 1, mark: 'HL', lengthCm: 40, widthCm: 30, heightCm: 20, grossKg: 5, items: [
        PackItem(code: 'A', jan: '4909999000014', quantity: 2),
        PackItem(code: 'B', quantity: 3),
      ]),
    ], header: const PlHeader(consignee: 'ACME <LTD>'));
    expect(html, contains('ACME &lt;LTD&gt;'));
    expect(html, contains('<td class="miss"></td>'));
    expect('class="first"'.allMatches(html).length, 1);
    expect(html, contains('Total cartons 箱数</td><td>1'));
  });
}
