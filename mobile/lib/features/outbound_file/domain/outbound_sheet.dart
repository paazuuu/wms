import 'package:equatable/equatable.dart';

import '../../../core/export/xlsx.dart' show XlsxSheetRows;

/// What a column of a shipping list (出荷リスト, e.g. the 明细 sheet) holds.
enum OutboundColumn {
  jan,
  quantity,
  code,
  maker,
  name,
  supplier,
  unitPrice,
  unitPriceTax,
  listPrice,
  amount,
  taxRate,
  orderNumber,
  arrival,
  orderDate;

  /// What the column is called on the server (outbound_files.columns).
  String get wire => switch (this) {
        jan => 'jan',
        quantity => 'quantity',
        code => 'code',
        maker => 'maker',
        name => 'name',
        supplier => 'supplier',
        unitPrice => 'unit_price',
        unitPriceTax => 'unit_price_tax',
        listPrice => 'list_price',
        amount => 'amount',
        taxRate => 'tax_rate',
        orderNumber => 'order_number',
        arrival => 'arrival',
        orderDate => 'order_date',
      };
}

/// A heading as compared: lower case, half-width, without spaces, brackets
/// and marks — 「单价（税前）」 → 单价税前, "Unit Price (excl.)" → unitpriceexcl.
String outboundHeadingKey(String s) {
  final b = StringBuffer();
  for (final c in s.runes) {
    b.writeCharCode(c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : c);
  }
  return b.toString().toLowerCase().replaceAll(RegExp(r'[\s　_\-()（）\[\]【】「」・/／.,:：#№%]'), '');
}

// Exact headings, in Japanese, Chinese, English and Korean.
const _exact = <OutboundColumn, Set<String>>{
  OutboundColumn.jan: {
    'jan', 'janコード', 'jancode', 'janno', 'jan番号', 'ジャパンコード', 'japanコード', 'japancode', 'バーコード', 'barcode',
    'ean', 'ean13', 'eancode', 'upc', 'gtin', '条码', '条形码', '商品条码', '国际条码', 'jan码', '바코드', 'jan코드',
  },
  OutboundColumn.quantity: {
    '数量', '数', '個数', '出荷数', '出荷数量', '出庫数', '出庫数量', '発送数', 'qty', 'quantity', 'pcs', '个数', '件数',
    '发货数量', '出库数量', '出货数量', '수량', '出荷個数',
  },
  OutboundColumn.code: {
    '品番', '型番', '商品コード', '品号', '型号', '货号', '商品编号', '产品编号', 'sku', 'itemcode', 'itemno', 'productcode',
    'partno', 'partnumber', 'model', 'modelno', '품번', '모델',
  },
  OutboundColumn.maker: {
    'メーカー', 'メーカー名', 'maker', 'brand', 'manufacturer', '品牌', '厂家', '厂商', '制造商', '生产厂家', '브랜드', '제조사',
    'ブランド',
  },
  OutboundColumn.name: {
    '商品名', '品名', '名称', 'name', 'productname', 'itemname', 'description', '产品名称', '商品名称', '品名称', '产品名',
    '상품명', '제품명',
  },
  OutboundColumn.supplier: {
    '仕入先', '仕入先名', '供給元', '仕入れ先', '供货商', '供应商', 'supplier', 'vendor', '공급처', '공급업체', '問屋',
  },
  OutboundColumn.unitPrice: {
    '単価', '単価税抜', '税抜単価', '税抜', '税抜価格', '单价', '单价税前', '税前单价', '单价不含税', '不含税单价', '单价税拔',
    'unitprice', 'price', 'netprice', 'unitpriceexcl', 'unitpriceexcltax', 'priceexcltax', '단가', '仕入単価', '仕入値',
    '仕入れ値', '原価',
  },
  OutboundColumn.unitPriceTax: {
    '単価税込', '税込単価', '税込', '税込価格', '单价税入', '单价含税', '含税单价', '税后单价', '单价税込', 'unitpriceincl',
    'unitpriceincltax', 'priceincltax', 'grossprice',
  },
  OutboundColumn.listPrice: {
    '定価', '上代', '定価税抜', '希望小売価格', '零售价', '零售价税拔', '零售价税抜', '零售价税前', '标价', '定价', 'listprice',
    'retailprice', 'msrp', '소비자가',
  },
  OutboundColumn.amount: {
    '金額', '合計', '合計金額', '小計', '金额', '合计', '小计', '总价', '总金额', 'amount', 'total', 'subtotal', '합계', '금액',
  },
  OutboundColumn.taxRate: {'税率', 'taxrate', 'tax', '세율'},
  OutboundColumn.orderNumber: {
    '注番', '注文番号', '発注番号', '注文no', 'オーダー番号', '订单号', '订单编号', 'orderno', 'ordernumber', 'po', 'pono',
    '주문번호',
  },
  OutboundColumn.arrival: {
    '到货时间', '到货日期', '入荷日', '納品日', '着荷日', '到着日', 'arrival', 'arrivaldate', 'deliverydate', '도착일',
  },
  OutboundColumn.orderDate: {'下单时间', '下单日期', '発注日', '注文日', 'orderdate', '주문일'},
};

/// What one heading means, or null: an exact heading first, else its words
/// (a 単価 with 税込 in it, a JAN in "JANコード(13桁)").
OutboundColumn? outboundColumnOf(String heading) {
  final k = outboundHeadingKey(heading);
  if (k.isEmpty) return null;
  for (final e in _exact.entries) {
    if (e.value.contains(k)) return e.key;
  }
  bool has(List<String> words) => words.any(k.contains);
  // Totals of weight, boxes and so on are not ours to read.
  if (has(['重量', '重さ', 'weight', '箱', 'box', 'サイズ', 'size'])) return null;
  final price = has(['単価', '单价', '价', '価格', 'price', '단가']);
  if (price && has(['税込', '税入', '含税', '税后', 'incl', 'gross'])) return OutboundColumn.unitPriceTax;
  if (has(['零售', '定価', '上代', 'retail', 'list'])) return OutboundColumn.listPrice;
  if (price) return OutboundColumn.unitPrice;
  if (has(['jan', 'ean', '条码', 'バーコード', 'barcode', 'ジャパンコード'])) return OutboundColumn.jan;
  if (has(['数量', 'qty', 'quantity', '수량'])) return OutboundColumn.quantity;
  if (has(['品番', '型番', '型号', '货号', 'sku'])) return OutboundColumn.code;
  if (has(['メーカー', '品牌', '厂', 'brand', 'maker'])) return OutboundColumn.maker;
  if (has(['仕入先', '供货', '供应', 'supplier', 'vendor'])) return OutboundColumn.supplier;
  if (has(['金額', '金额', '合計', '合计', 'amount', 'total'])) return OutboundColumn.amount;
  if (has(['注番', '订单', 'order no', 'orderno'])) return OutboundColumn.orderNumber;
  return null;
}

/// A JAN as read: half-width digits, 8 (JAN-8), 12 (UPC), 13 or 14 long;
/// anything else is not one ('' ).
String normalizeOutboundJan(String raw) {
  final b = StringBuffer();
  for (final c in raw.trim().runes) {
    b.writeCharCode(c >= 0xFF10 && c <= 0xFF19 ? c - 0xFEE0 : c);
  }
  final t = b.toString().replaceAll(RegExp(r'[\s\-]'), '');
  if (!RegExp(r'^\d+$').hasMatch(t)) return '';
  return const {8, 12, 13, 14}.contains(t.length) ? t : '';
}

double? _num(String s) {
  final b = StringBuffer();
  for (final c in s.trim().runes) {
    b.writeCharCode(c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : c);
  }
  final t = b.toString().replaceAll(RegExp(r'[,，\s¥￥円元$]'), '');
  return double.tryParse(t);
}

/// One row of the list as read.
class OutboundRow extends Equatable {
  const OutboundRow({
    required this.rowNo,
    this.jan = '',
    this.janRaw = '',
    this.quantity,
    this.code,
    this.maker,
    this.name,
    this.supplier,
    this.unitPrice,
    this.unitPriceTax,
    this.listPrice,
    this.amount,
    this.taxRate,
    this.orderNumber,
    this.arrival,
    this.orderDate,
    this.raw = const {},
  });

  /// The sheet's row (1 = the first).
  final int rowNo;

  /// A JAN that is one, or ''.
  final String jan;

  /// What the JAN cell held.
  final String janRaw;
  final int? quantity;
  final String? code;
  final String? maker;
  final String? name;
  final String? supplier;

  /// 税抜 and 税込, as written (either may be missing).
  final double? unitPrice;
  final double? unitPriceTax;
  final double? listPrice;
  final double? amount;
  final double? taxRate;
  final String? orderNumber;
  final String? arrival;
  final String? orderDate;

  /// The row as it was: heading → cell.
  final Map<String, String> raw;

  /// The JAN cell held something that is not a JAN.
  bool get janInvalid => jan.isEmpty && janRaw.trim().isNotEmpty;

  double get rate => (taxRate == null || taxRate! <= 0) ? 10 : (taxRate! < 1 ? taxRate! * 100 : taxRate!);

  /// 税抜, from 税込 when only that was written.
  double? get priceEx => unitPrice ?? (unitPriceTax == null ? null : _round2(unitPriceTax! / (1 + rate / 100)));

  /// 税込, from 税抜 when only that was written.
  double? get priceTax => unitPriceTax ?? (unitPrice == null ? null : _round2(unitPrice! * (1 + rate / 100)));

  /// The row's amount: as written, else quantity × 税込.
  double? get total => amount ?? (quantity == null || priceTax == null ? null : _round2(quantity! * priceTax!));

  @override
  List<Object?> get props => [rowNo, jan, janRaw, quantity, code, maker, supplier, unitPrice, unitPriceTax, amount];
}

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// A shipping list as read from one sheet: where its headings are, what each
/// column means, its rows.
class OutboundSheet extends Equatable {
  const OutboundSheet({
    required this.sheetName,
    required this.headerRow,
    required this.headings,
    required this.columns,
    required this.rows,
    this.janGuessed = false,
  });

  final String sheetName;

  /// 0-based; -1 when no heading was found.
  final int headerRow;
  final List<String> headings;
  final Map<OutboundColumn, int> columns;
  final List<OutboundRow> rows;

  /// The JAN column was found by what it holds, not by its heading.
  final bool janGuessed;

  /// Readable as a list: a quantity and something to find the product by.
  bool get usable =>
      columns.containsKey(OutboundColumn.quantity) &&
      (columns.containsKey(OutboundColumn.jan) || columns.containsKey(OutboundColumn.code));

  Map<String, String> get columnsWire => {
        for (final e in columns.entries)
          e.key.wire: e.value < headings.length && headings[e.value].isNotEmpty ? headings[e.value] : '#${e.value + 1}',
      };

  @override
  List<Object?> get props => [sheetName, headerRow, headings, columns, rows, janGuessed];
}

/// The columns of a heading row.
Map<OutboundColumn, int> outboundColumnsOf(List<String> headings) {
  final out = <OutboundColumn, int>{};
  for (final (i, h) in headings.indexed) {
    final c = outboundColumnOf(h);
    if (c != null && !out.containsKey(c)) out[c] = i;
  }
  return out;
}

/// The column that holds JANs by what is in it: most of its filled cells
/// are 8 or 13 digits.
int? guessJanColumn(List<List<String>> rows, int from, {Set<int> taken = const {}}) {
  final hits = <int, int>{};
  final filled = <int, int>{};
  for (var r = from; r < rows.length && r < from + 200; r++) {
    for (final (c, v) in rows[r].indexed) {
      if (taken.contains(c) || v.trim().isEmpty) continue;
      filled[c] = (filled[c] ?? 0) + 1;
      final j = normalizeOutboundJan(v);
      if (j.length == 13 || j.length == 8) hits[c] = (hits[c] ?? 0) + 1;
    }
  }
  int? best;
  for (final e in hits.entries) {
    final f = filled[e.key] ?? 0;
    if (e.value >= 2 && e.value >= f * 0.6 && (best == null || e.value > hits[best]!)) best = e.key;
  }
  return best;
}

/// Reads one sheet. The heading row is, among the first 15, the one whose
/// cells mean the most; [columns] (chosen by hand) replace what was found.
/// Rows with nothing to ship by — no quantity and no JAN or 品番 (a total,
/// a blank) — are left out.
OutboundSheet parseOutboundSheet(String sheetName, List<List<String>> rows, {Map<OutboundColumn, int>? columns}) {
  var head = -1;
  var found = <OutboundColumn, int>{};
  for (var r = 0; r < rows.length && r < 15; r++) {
    final c = outboundColumnsOf(rows[r]);
    final score = c.length + (c.containsKey(OutboundColumn.quantity) ? 2 : 0) + (c.containsKey(OutboundColumn.jan) ? 2 : 0);
    final best = found.length + (found.containsKey(OutboundColumn.quantity) ? 2 : 0) + (found.containsKey(OutboundColumn.jan) ? 2 : 0);
    if (c.length >= 2 && score > best) {
      head = r;
      found = c;
    }
  }
  final headings = head >= 0 ? rows[head] : const <String>[];
  var guessed = false;
  if (!found.containsKey(OutboundColumn.jan)) {
    final g = guessJanColumn(rows, head + 1, taken: found.values.toSet());
    if (g != null) {
      found[OutboundColumn.jan] = g;
      guessed = true;
    }
  }
  final cols = columns ?? found;
  String at(List<String> row, OutboundColumn c) {
    final i = cols[c];
    return i == null || i >= row.length ? '' : row[i].trim();
  }

  String? text(List<String> row, OutboundColumn c) {
    final v = at(row, c);
    return v.isEmpty ? null : v;
  }

  final out = <OutboundRow>[];
  for (var r = head + 1; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((c) => c.trim().isEmpty)) continue;
    final janRaw = at(row, OutboundColumn.jan);
    final qty = _num(at(row, OutboundColumn.quantity));
    final code = text(row, OutboundColumn.code);
    // A total (合计 under the JAN) or a blank: nothing to ship by.
    if (qty == null && normalizeOutboundJan(janRaw).isEmpty && code == null) continue;
    out.add(OutboundRow(
      rowNo: r + 1,
      jan: normalizeOutboundJan(janRaw),
      janRaw: janRaw,
      quantity: qty?.round(),
      code: code,
      maker: text(row, OutboundColumn.maker),
      name: text(row, OutboundColumn.name),
      supplier: text(row, OutboundColumn.supplier),
      unitPrice: _num(at(row, OutboundColumn.unitPrice)),
      unitPriceTax: _num(at(row, OutboundColumn.unitPriceTax)),
      listPrice: _num(at(row, OutboundColumn.listPrice)),
      amount: _num(at(row, OutboundColumn.amount)),
      taxRate: _num(at(row, OutboundColumn.taxRate)),
      orderNumber: text(row, OutboundColumn.orderNumber)?.replaceAll(RegExp(r'\s+'), ' '),
      arrival: text(row, OutboundColumn.arrival),
      orderDate: text(row, OutboundColumn.orderDate),
      raw: {
        for (final (i, v) in row.indexed)
          if (v.trim().isNotEmpty) (i < headings.length && headings[i].trim().isNotEmpty ? headings[i].trim() : '#${i + 1}'): v.trim(),
      },
    ));
  }
  return OutboundSheet(
    sheetName: sheetName,
    headerRow: head,
    headings: headings,
    columns: cols,
    rows: out,
    janGuessed: guessed && columns == null,
  );
}

/// Which sheet of a workbook is the shipping list: the one read best (a
/// quantity and a JAN or 品番), a name such as 明细 / 出荷 deciding a tie.
int pickOutboundSheet(List<XlsxSheetRows> sheets) {
  var best = 0;
  var bestScore = -1;
  for (final (i, s) in sheets.indexed) {
    final p = parseOutboundSheet(s.name, s.rows);
    final c = p.columns;
    var score = (c.containsKey(OutboundColumn.quantity) ? 4 : 0) +
        (c.containsKey(OutboundColumn.jan) ? 4 : 0) +
        (c.containsKey(OutboundColumn.code) ? 2 : 0) +
        c.length;
    if (RegExp(r'明细|明細|出荷|出库|出庫|发货|発送|ship', caseSensitive: false).hasMatch(s.name)) score += 3;
    if (score > bestScore) {
      best = i;
      bestScore = score;
    }
  }
  return best;
}
