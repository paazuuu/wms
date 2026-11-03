import 'dart:typed_data';

import '../../../core/export/xlsx.dart';
import '../../product/domain/product.dart';

/// The headings of the shipping list as people already write it (the 明细
/// sheet), then each product's weight and the line's total weight.
const shippingListHeaders = [
  '下单时间', '到货时间', '编号', '供货商', '品牌', '品番', 'ジャパンコード', '数量',
  '零售价（税拔）', '单价（税前）', '单价（税入）', '合计', '注番', '重量（g/個）', '総重量（kg）',
];

double _r2(double v) => (v * 100).roundToDouble() / 100;

/// 商品ライブラリー in the shipping list's own layout, ready to fill in and
/// read back by 出荷リストで出庫: a product a row with its supplier, maker,
/// 品番, JAN, the stock that can go out as the quantity, its prices and
/// weight. 单价（税入）, 合计 and 総重量 are formulas (=J×1.1, =H×K,
/// =H×N÷1000), so changing a quantity changes the amount and the weight;
/// the totals row sums them.
Uint8List buildShippingListXlsx(List<Product> products) {
  final rows = <List<Object?>>[];
  for (final (i, p) in products.indexed) {
    final n = i + 2;
    final primary = p.suppliers.where((s) => s.isPrimary).firstOrNull ?? p.suppliers.firstOrNull;
    final qty = p.stock?.available ?? 0;
    final ex = primary?.unitPrice;
    final tax = ex == null ? null : _r2(ex * 1.1);
    final w = p.unitWeightG;
    rows.add([
      null,
      null,
      null,
      primary?.name,
      p.maker,
      p.sku,
      p.janCode,
      qty,
      p.listPrice,
      ex,
      XlsxFormula('J$n*1.1', cached: tax),
      XlsxFormula('H$n*K$n', cached: tax == null ? 0 : _r2(qty * tax)),
      null,
      w,
      XlsxFormula('H$n*N$n/1000', cached: w == null ? 0 : qty * w / 1000),
    ]);
  }
  final last = products.length + 1;
  return buildXlsx(
    sheetName: '明细',
    headers: shippingListHeaders,
    rows: rows,
    widths: [10, 10, 8, 16, 14, 18, 16, 8, 12, 12, 12, 12, 12, 12, 12],
    bottom: products.isEmpty
        ? const []
        : [
            [
              null, null, null, null, null, null, '合计',
              XlsxFormula('SUM(H2:H$last)'),
              null, null, null,
              XlsxFormula('SUM(L2:L$last)'),
              null, null,
              XlsxFormula('SUM(O2:O$last)'),
            ],
          ],
  );
}
