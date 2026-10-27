import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/master_import/domain/master_import.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_file.dart';
import 'package:wms_mobile/features/stock_import/presentation/reading_export.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));

  test('a purchase ledger (明細) is read here, its Chinese headings and every column kept', () {
    final sheet = parseStockRows([
      ['下单时间', '到货时间', '编号', '供货商', '品牌', '品番', 'ジャパンコード', '数量', '零售价（税拔）', '单价（税前）', '单价（税入）', '合计', '注番'],
      ['9.20', '10.1', 'A-1', 'テスト商事', 'テスト', 'TP-07B', '4909999000014', '1,000 ', '100', '50 ', '55', '55000', 'BL 9E'],
      ['9.20', '10.1', 'A-2', 'テスト商事', 'テスト', 'TP-07B', '4909999000014', '2,000 ', '100', '50 ', '', '110000', 'HL 9E'],
      ['', '', '', 'テスト商事', 'テスト', 'TN-A5', '', '20', '', '110', '', '2200', 'BL 9D'],
    ]);
    expect(sheet.header, isTrue);
    // One stock line for the JAN, its two rows summed; the row with no JAN is a problem.
    expect(sheet.lines.single.quantity, 3000);
    expect(sheet.lines.single.maker, 'テスト');
    expect(sheet.problems.single.code, 'no_jan');
    // Every row kept as read, each with its own 注番 and prices.
    expect(sheet.read.length, 3);
    final g = sheet.read[1].ledger;
    expect([g.orderDate, g.deliveryDate, g.serial, g.supplier, g.orderNumber], ['9.20', '10.1', 'A-2', 'テスト商事', 'HL 9E']);
    expect([g.listPrice, g.unitPrice, g.amount], ['100', '50', '110000']);
    // 税込 as written, else 税抜 with 10%.
    expect(sheet.read[0].ledger.unitPriceWithTax, '55');
    expect(g.unitPriceWithTax, '55');
    expect(const LedgerFields(unitPrice: '49').unitPriceWithTax, '53.9');
    expect(const LedgerFields(unitPrice: '100', taxRate: '8%').unitPriceWithTax, '108');
    expect(const LedgerFields().unitPriceWithTax, '');
  });

  test('a row keeps its ledger columns through what the import stores', () {
    const row = ReadRow(
      lineNo: 3,
      jan: '4909999000014',
      name: 'テストペン',
      quantity: '40',
      ledger: LedgerFields(deliveryDate: '8月27日', serial: '2', unitPrice: '307', amount: '12280'),
    );
    final back = ReadRow.fromJson(row.toJson());
    expect(back, row);
    expect(row.toJson().containsKey('order_number'), isFalse);
    // What the reader gave is taken as it came, numbers too.
    final l = MasterLine.fromRead(const {'jan_code': '4909999000014', 'unit_price': 307.0, 'amount': 12280, 'delivery_date': '8月27日'}, 1);
    expect(LedgerFields.fromJson(l.ledger), const LedgerFields(unitPrice: '307', amount: '12280', deliveryDate: '8月27日'));
  });

  test('the reading laid out as the ledger: its columns first, the document’s supplier where a line names none', () {
    final m = MasterImport(
      id: 17,
      status: MasterImportStatus.awaitingInspection,
      supplierName: 'テスト商事',
      readLines: [
        const ReadRow(
          lineNo: 2,
          jan: '4909999000014',
          name: 'TP-07B',
          quantity: '40',
          maker: 'テスト',
          code: 'TP-07B',
          ledger: LedgerFields(deliveryDate: '8月27日', serial: '2', unit: '本', unitPrice: '307', amount: '12280'),
        ).toJson(),
      ],
    );
    final t = readingTable(ja, m);
    expect(t.headers.take(16), [
      '行', '発注日', '入荷日', '番号', '仕入先', 'メーカー', '品番', 'JANコード', '商品名', '数量', '単位',
      '定価（税抜）', '単価（税抜）', '単価（税込）', '金額', '注番',
    ]);
    expect(t.rows.single.take(16), [
      2, '', '8月27日', '2', 'テスト商事', 'テスト', 'TP-07B', '4909999000014', 'TP-07B', '40', '本', '', '307', '337.7', '12280', '',
    ]);
  });

  test('a line with no name but a 品番 is registered under its 品番', () {
    const noName = StockFileLine(lineNo: 1, janCode: '4909999000014', quantity: 3, maker: 'パイロット', code: 'BIL80EFSULB');
    expect(noName.registerName, 'BIL80EFSULB');
    expect(noName.toPriceBookLine()['product_name'], 'BIL80EFSULB');
    const named = StockFileLine(lineNo: 1, janCode: '4909999000014', quantity: 3, name: 'テストペン', code: 'TP-07B');
    expect(named.registerName, 'テストペン');
    expect(const StockFileLine(lineNo: 1, janCode: '4909999000014', quantity: 3).registerName, isNull);
  });
}
