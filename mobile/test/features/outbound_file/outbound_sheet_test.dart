import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/outbound_file/data/outbound_file_repository.dart';
import 'package:wms_mobile/features/outbound_file/data/shipping_list_export.dart';
import 'package:wms_mobile/features/outbound_file/domain/outbound_plan.dart';
import 'package:wms_mobile/features/outbound_file/domain/outbound_sheet.dart';
import 'package:wms_mobile/features/product/domain/product.dart';

/// A 明细 sheet the way people write it: Chinese and Japanese headings, a
/// row without a JAN, a JAN-8, a total row.
const _meisai = <List<String>>[
  ['下单时间', '到货时间', '编号', '供货商', '品牌', '品番', 'ジャパンコード', '数量', '零售价（税拔）', '单价（税前）', '单价（税入）', '合计', '注番'],
  ['', '10.1', '', 'テスト卸', 'テスト文具', 'TS-100', '4909999000014', '1000', '100', '50', '55', '55000', 'BL        9E'],
  ['', '', '', 'テスト卸', 'テスト文具', 'TS-200', '', '200', '', '49', '53.9', '10780', 'HL'],
  ['', '10.2', '', 'サンプル商事', 'サンプル', 'SP-1', '49999990', '20', '', '', '110', '', ''],
  [],
  ['', '', '', '', '', '', '', '', '', '', '', '65780', ''],
];

void main() {
  group('reading a shipping list', () {
    test('headings in any language mean their columns', () {
      expect(outboundColumnOf('ジャパンコード'), OutboundColumn.jan);
      expect(outboundColumnOf('条形码'), OutboundColumn.jan);
      expect(outboundColumnOf('JANコード(13桁)'), OutboundColumn.jan);
      expect(outboundColumnOf('Qty'), OutboundColumn.quantity);
      expect(outboundColumnOf('单价（税前）'), OutboundColumn.unitPrice);
      expect(outboundColumnOf('单价（税入）'), OutboundColumn.unitPriceTax);
      expect(outboundColumnOf('税込単価'), OutboundColumn.unitPriceTax);
      expect(outboundColumnOf('Unit Price (incl. tax)'), OutboundColumn.unitPriceTax);
      expect(outboundColumnOf('零售价（税拔）'), OutboundColumn.listPrice);
      expect(outboundColumnOf('供货商'), OutboundColumn.supplier);
      expect(outboundColumnOf('品牌'), OutboundColumn.maker);
      expect(outboundColumnOf('品番'), OutboundColumn.code);
      expect(outboundColumnOf('注番'), OutboundColumn.orderNumber);
      // Weights and boxes are not ours to read.
      expect(outboundColumnOf('総重量（kg）'), isNull);
      expect(outboundColumnOf('重量（g/個）'), isNull);
    });

    test('a 明细 sheet: every row with what it holds, the total left out', () {
      final s = parseOutboundSheet('明细', _meisai);
      expect(s.headerRow, 0);
      expect(s.usable, isTrue);
      expect(s.columns[OutboundColumn.jan], 6);
      expect(s.columns[OutboundColumn.quantity], 7);
      expect(s.rows.map((r) => r.rowNo), [2, 3, 4]);
      final first = s.rows.first;
      expect(first.jan, '4909999000014');
      expect(first.code, 'TS-100');
      expect(first.maker, 'テスト文具');
      expect(first.supplier, 'テスト卸');
      expect(first.quantity, 1000);
      expect(first.priceEx, 50);
      expect(first.priceTax, 55);
      expect(first.total, 55000);
      expect(first.orderNumber, 'BL 9E');
      expect(first.arrival, '10.1');
      expect(first.raw['ジャパンコード'], '4909999000014');
      // No JAN: found later by its 品番.
      expect(s.rows[1].jan, isEmpty);
      expect(s.rows[1].janInvalid, isFalse);
      // A JAN-8, and only 税込 written: 税抜 worked out at 10%.
      expect(s.rows[2].jan, '49999990');
      expect(s.rows[2].priceEx, 100);
      expect(s.rows[2].total, 2200);
    });

    test('with no JAN heading the column is found by what it holds', () {
      final s = parseOutboundSheet('list', const [
        ['Code', 'Barcode No', 'Qty'],
        ['A-1', '4909999000014', '3'],
        ['A-2', '4909999000021', '4'],
      ]);
      expect(s.columns[OutboundColumn.jan], 1);

      final guessed = parseOutboundSheet('list', const [
        ['Item', 'Number', 'Qty'],
        ['Pen', '4909999000014', '3'],
        ['Note', '4909999000021', '4'],
      ]);
      expect(guessed.columns[OutboundColumn.jan], 1);
      expect(guessed.janGuessed, isTrue);
      expect(guessed.rows.first.jan, '4909999000014');
    });

    test('full-width digits and a JAN that is not one', () {
      expect(normalizeOutboundJan('４９０９９９９００００１４'), '4909999000014');
      expect(normalizeOutboundJan('49099990000'), isEmpty);
      final s = parseOutboundSheet('x', const [
        ['JAN', '数量'],
        ['ABC', '２'],
      ]);
      expect(s.rows.single.janInvalid, isTrue);
      expect(s.rows.single.quantity, 2);
    });

    test('columns chosen by hand replace what was found', () {
      final s = parseOutboundSheet('明细', _meisai, columns: {OutboundColumn.jan: 5, OutboundColumn.quantity: 7});
      expect(s.rows.first.jan, isEmpty);
      expect(s.rows.first.janRaw, 'TS-100');
      expect(s.rows.first.code, isNull);
    });

    test('the shipping list is the sheet read best, its name deciding a tie', () {
      final sheets = <XlsxSheetRows>[
        (name: 'PL-BL', rows: const [['箱番号', '品名', 'メーカー', '品番', '数量'], ['1', 'Pen', 'X', 'TS-100', '10']]),
        (name: '明细', rows: _meisai),
      ];
      expect(pickOutboundSheet(sheets), 1);
    });
  });

  group('the plan', () {
    const pen = OutboundMatch(matchedBy: OutboundMatchedBy.jan, productId: 1, jan: '4909999000014', name: 'ペン', onHand: 1200, unitWeightG: 10);
    test('one stock for the same product on several rows; what is short is short', () {
      final rows = [
        const OutboundRow(rowNo: 2, jan: '4909999000014', quantity: 1000, unitPriceTax: 55),
        const OutboundRow(rowNo: 3, jan: '4909999000014', quantity: 500),
        const OutboundRow(rowNo: 4, jan: '4909999000045', quantity: 5),
        const OutboundRow(rowNo: 5, code: 'TS-200', quantity: 5),
        const OutboundRow(rowNo: 6, code: 'TS-300', quantity: 5),
        const OutboundRow(rowNo: 7, jan: '4909999000014'),
      ];
      final plan = planOutbound(rows, [
        pen,
        pen,
        OutboundMatch.none,
        OutboundMatch.none,
        const OutboundMatch(matchedBy: OutboundMatchedBy.several, candidates: [
          OutboundCandidate(productId: 2, jan: '4909999000021', name: 'A'),
          OutboundCandidate(productId: 3, jan: '4909999000038', name: 'B'),
        ]),
        pen,
      ]);
      expect([for (final l in plan) l.status], [
        OutboundStatus.ok,
        OutboundStatus.short,
        OutboundStatus.unknownJan,
        OutboundStatus.noJan,
        OutboundStatus.several,
        OutboundStatus.noQuantity,
      ]);
      expect([for (final l in plan) l.action], [
        OutboundAction.ship,
        OutboundAction.ship,
        OutboundAction.record,
        OutboundAction.record,
        OutboundAction.record,
        OutboundAction.skip,
      ]);
      expect(plan[0].shipped, 1000);
      expect(plan[1].stockBefore, 200);
      expect(plan[1].shipped, 200);
      expect(plan[1].short, 300);
      final t = OutboundPlanTotals.of(plan);
      expect(t.shipped, 1200);
      expect(t.short, 300);
      expect(t.shortRows, 1);
      expect(t.weightG, 12000);
      expect(t.amount, 55000);
      // Posted as read, with what was decided.
      final post = plan[0].toPost().toJson();
      expect(post['action'], 'ship');
      expect(post['product_id'], 1);
      expect(post['unit_price'], 50);
      expect(post['unit_price_tax'], 55);
    });

    test('a row left out frees its stock; a product chosen by hand is shipped', () {
      final rows = [
        const OutboundRow(rowNo: 2, jan: '4909999000014', quantity: 1000),
        const OutboundRow(rowNo: 3, jan: '4909999000014', quantity: 500),
        const OutboundRow(rowNo: 4, code: 'TS-200', quantity: 5),
      ];
      final plan = planOutbound(rows, [pen, pen, OutboundMatch.none],
          chosen: {2: OutboundAction.skip},
          picked: {4: const OutboundMatch(matchedBy: OutboundMatchedBy.picked, productId: 9, onHand: 5)});
      expect(plan[0].shipped, 0);
      expect(plan[1].status, OutboundStatus.ok);
      expect(plan[1].shipped, 500);
      expect(plan[2].status, OutboundStatus.ok);
      expect(plan[2].action, OutboundAction.ship);
      expect(plan[2].toPost().matchedBy, 'picked');
      // Asking to ship a row with no product keeps it as a record.
      final none = planOutbound([rows[2]], [OutboundMatch.none], chosen: {4: OutboundAction.ship});
      expect(none.single.action, OutboundAction.record);
    });
  });

  test('代理出荷: every row a record, even one with a product and stock', () {
    const pen = OutboundMatch(matchedBy: OutboundMatchedBy.jan, productId: 1, onHand: 100);
    final plan = planOutbound(
      [const OutboundRow(rowNo: 2, jan: '4909999000014', quantity: 5), const OutboundRow(rowNo: 3, code: 'X'), const OutboundRow(rowNo: 4, code: 'Y', quantity: 1)],
      [pen, OutboundMatch.none, OutboundMatch.none],
      chosen: {2: OutboundAction.ship},
      proxy: true,
    );
    expect([for (final l in plan) l.action], [OutboundAction.record, OutboundAction.skip, OutboundAction.record]);
    expect(plan.every((l) => l.shipped == 0 && l.short == 0), isTrue);
  });

  group('the shipping-format Excel', () {
    const products = [
      Product(
        id: 1,
        janCode: '4909999000014',
        name: 'テストペン',
        maker: 'テスト文具',
        sku: 'TS-100',
        listPrice: 100,
        unitWeightG: 12.5,
        stock: ProductStock(onHand: 40, available: 30),
        suppliers: [ProductSupplierRef(id: 1, name: 'テスト卸', unitPrice: 50, isPrimary: true)],
      ),
      Product(id: 2, janCode: '4909999000021', name: 'テストノート'),
    ];

    test('the 明细 layout with weight, and formulas for the amount and weight', () {
      final bytes = buildShippingListXlsx(products);
      final rows = readXlsx(bytes);
      expect(rows.first, shippingListHeaders);
      expect(rows[1].sublist(3, 8), ['テスト卸', 'テスト文具', 'TS-100', '4909999000014', '30']);
      // Cached values for readers that do not work formulas out.
      expect(rows[1][10], '55');
      expect(rows[1][11], '1650');
      expect(rows[1][13], '12.5');
      expect(rows[1][14], '0.375');
      expect(rows.last[6], '合计');
      final sheet = utf8.decode(ZipDecoder().decodeBytes(bytes).findFile('xl/worksheets/sheet1.xml')!.readBytes()!);
      expect(sheet, contains('<f>J2*1.1</f>'));
      expect(sheet, contains('<f>H2*K2</f>'));
      expect(sheet, contains('<f>H2*N2/1000</f>'));
      expect(sheet, contains('<f>SUM(O2:O3)</f>'));
      final book = utf8.decode(ZipDecoder().decodeBytes(bytes).findFile('xl/workbook.xml')!.readBytes()!);
      expect(book, contains('fullCalcOnLoad="1"'));
    });

    test('read back by 出荷リストで出庫: the weights are not read, the total row is left out', () {
      final sheets = readXlsxSheets(buildShippingListXlsx(products));
      final s = parseOutboundSheet(sheets.single.name, sheets.single.rows);
      expect(s.usable, isTrue);
      expect(s.rows.map((r) => r.jan), ['4909999000014', '4909999000021']);
      expect(s.rows.first.quantity, 30);
      expect(s.rows.first.priceEx, 50);
      expect(s.rows.first.priceTax, 55);
      expect(s.columns.values, isNot(contains(13)));
      expect(s.columns.values, isNot(contains(14)));
    });
  });

  test('every sheet of a workbook, with its row numbers', () {
    final bytes = buildXlsxBook([
      const XlsxSheet(name: 'A', headers: ['x'], rows: [['1']]),
      const XlsxSheet(name: '明细', headers: ['JAN', '数量'], rows: [['4909999000014', 2]], top: [['見出しの上'], []]),
    ]);
    final sheets = readXlsxSheets(bytes);
    expect(sheets.map((s) => s.name), ['A', '明细']);
    expect(sheets[1].rows[0], ['見出しの上']);
    expect(sheets[1].rows[1], isEmpty);
    expect(sheets[1].rows[2], ['JAN', '数量']);
    expect(readXlsx(bytes), [['x'], ['1']]);
  });
}
