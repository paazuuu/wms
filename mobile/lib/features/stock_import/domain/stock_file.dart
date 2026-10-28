import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:equatable/equatable.dart';

import '../../../core/export/xlsx.dart';
import '../../qc/domain/inspection.dart' show normalizeJan;

/// How a stock file's quantities are taken (0144).
enum StockFileMode {
  /// Each quantity is added to what the warehouse has.
  add('add'),

  /// The warehouse's stock becomes each quantity.
  set('set');

  const StockFileMode(this.wire);
  final String wire;
}

/// One product's quantity from a stock file. [lineNo] is the sheet's own
/// row number, so a problem can say where to look.
class StockFileLine extends Equatable {
  const StockFileLine({
    required this.lineNo,
    required this.janCode,
    required this.quantity,
    this.name,
    this.merged = 1,
    this.doubtful = false,
    this.maker,
    this.code,
  });

  final int lineNo;
  final String janCode;
  final int quantity;
  final String? name;

  /// The file's maker and 品番 for it, when it had them: what a product made
  /// from this line is registered with.
  final String? maker;
  final String? code;

  /// How many of the file's rows had this JAN (their quantities summed).
  final int merged;

  /// The AI was not sure of this line (its two readings disagreed, or the
  /// JAN's check digit failed): to be looked at before it goes in.
  final bool doubtful;

  StockFileLine copyWith({int? quantity}) => StockFileLine(
        lineNo: lineNo,
        janCode: janCode,
        quantity: quantity ?? this.quantity,
        name: name,
        merged: merged,
        doubtful: doubtful,
        maker: maker,
        code: code,
      );

  /// What a product made from this line is called: the file's name for it,
  /// else its 品番 (many invoices print only a maker and a 品番).
  String? get registerName {
    final n = (name ?? '').trim();
    if (n.isNotEmpty) return n;
    final c = (code ?? '').trim();
    return c.isEmpty ? null : c;
  }

  /// The line as 価格台帳 takes it, to register its product.
  Map<String, dynamic> toPriceBookLine() => {
        'jan_code': janCode,
        'product_name': registerName,
        if (maker != null) 'maker': maker,
        if (code != null) 'product_code': code,
      };

  Map<String, dynamic> toJson() => {'line_no': lineNo, 'jan_code': janCode, 'quantity': quantity};

  @override
  List<Object?> get props => [lineNo, janCode, quantity, name, merged, doubtful, maker, code];
}

/// A row the file had that cannot be taken: its row number and why.
class StockFileProblem extends Equatable {
  const StockFileProblem(this.lineNo, this.code, {this.value});

  final int lineNo;

  /// `no_jan`, `bad_quantity`, `not_item` (a row with neither a JAN nor a
  /// quantity: a branch name, an address, a blank — not a product at all).
  final String code;
  final String? value;

  @override
  List<Object?> get props => [lineNo, code, value];
}

/// One row of the file as it was read, before anything was made of it: its
/// JAN, name and quantity as the file has them, and what the reader was
/// unsure of. Kept with the import (0146) so it can be set beside the
/// original.
class ReadRow extends Equatable {
  const ReadRow({
    required this.lineNo,
    this.jan = '',
    this.name = '',
    this.quantity = '',
    this.maker = '',
    this.code = '',
    this.flags = const [],
    this.aiJan,
    this.aiQuantity,
    this.ledger = const LedgerFields(),
  });

  final int lineNo;
  final String jan;
  final String name;
  final String quantity;
  final String maker;
  final String code;
  final List<String> flags;

  /// The rest of a purchase ledger's (明細) columns, as the file wrote them.
  final LedgerFields ledger;

  /// What the AI had read, when this row comes from a 確認用Excel a person
  /// corrected: set beside what they wrote, so a correction is on record.
  final String? aiJan;
  final String? aiQuantity;

  /// A person changed the AI's JAN or quantity on the 確認用Excel.
  bool get corrected =>
      (aiJan != null && (normalizeJan(aiJan) ?? aiJan) != (normalizeJan(jan) ?? jan)) ||
      (aiQuantity != null && aiQuantity!.trim() != quantity.trim());

  Map<String, dynamic> toJson() => {
        'line_no': lineNo,
        'jan': jan,
        'name': name,
        'quantity': quantity,
        if (maker.isNotEmpty) 'maker': maker,
        if (code.isNotEmpty) 'code': code,
        if (flags.isNotEmpty) 'flags': flags,
        if (aiJan != null) 'ai_jan': aiJan,
        if (aiQuantity != null) 'ai_quantity': aiQuantity,
        ...ledger.toJson(),
      };

  factory ReadRow.fromJson(Map<String, dynamic> j) => ReadRow(
        lineNo: (j['line_no'] as num?)?.toInt() ?? 0,
        jan: '${j['jan'] ?? ''}',
        name: '${j['name'] ?? ''}',
        quantity: '${j['quantity'] ?? ''}',
        maker: '${j['maker'] ?? ''}',
        code: '${j['code'] ?? ''}',
        flags: [for (final f in (j['flags'] as List? ?? const [])) '$f'],
        aiJan: j['ai_jan']?.toString(),
        aiQuantity: j['ai_quantity']?.toString(),
        ledger: LedgerFields.fromJson(j),
      );

  ReadRow copyWith({
    String? jan,
    String? name,
    String? quantity,
    String? maker,
    String? code,
    List<String>? flags,
    String? aiJan,
    String? aiQuantity,
    LedgerFields? ledger,
  }) =>
      ReadRow(
        lineNo: lineNo,
        jan: jan ?? this.jan,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        maker: maker ?? this.maker,
        code: code ?? this.code,
        flags: flags ?? this.flags,
        aiJan: aiJan ?? this.aiJan,
        aiQuantity: aiQuantity ?? this.aiQuantity,
        ledger: ledger ?? this.ledger,
      );

  /// A person set it beside the original and found it right (or made it so).
  bool get humanChecked => flags.contains(humanCheckedFlag);

  /// A person left it out before the stock went in.
  bool get humanRemoved => flags.contains(humanRemovedFlag);

  ReadRow withFlags(List<String> flags) => ReadRow(
        lineNo: lineNo, jan: jan, name: name, quantity: quantity, maker: maker, code: code,
        aiJan: aiJan, aiQuantity: aiQuantity, ledger: ledger, flags: flags,
      );

  @override
  List<Object?> get props => [lineNo, jan, name, quantity, maker, code, flags, aiJan, aiQuantity, ledger];
}

/// Marks a person puts on a row read from a file: checked against the
/// original, changed, or left out.
const humanCheckedFlag = 'human_checked';
const humanCorrectedFlag = 'human_corrected';
const humanRemovedFlag = 'human_removed';

/// Flags that are a person's, not a doubt of the reader's.
const humanFlags = {humanCheckedFlag, humanCorrectedFlag, humanRemovedFlag};

/// A purchase ledger's (明細) columns beyond JAN, 品名, メーカー, 品番 and 数量
/// (0150), as text the way the file wrote them: 発注日, 入荷日, the line's own
/// number, the supplier named on it, 単位, 定価 (税抜), 単価 (税抜 and 税込),
/// 金額, 税率 and 注番. Empty when the file had no such column.
class LedgerFields extends Equatable {
  const LedgerFields({
    this.orderDate = '',
    this.deliveryDate = '',
    this.serial = '',
    this.supplier = '',
    this.unit = '',
    this.listPrice = '',
    this.unitPrice = '',
    this.unitPriceTax = '',
    this.amount = '',
    this.taxRate = '',
    this.orderNumber = '',
  });

  final String orderDate;
  final String deliveryDate;
  final String serial;
  final String supplier;
  final String unit;
  final String listPrice;
  final String unitPrice;
  final String unitPriceTax;
  final String amount;
  final String taxRate;
  final String orderNumber;

  static const _keys = [
    'order_date', 'delivery_date', 'serial', 'supplier', 'unit', 'list_price', 'unit_price', 'unit_price_tax',
    'amount', 'tax_rate', 'order_number',
  ];

  List<String> get _values =>
      [orderDate, deliveryDate, serial, supplier, unit, listPrice, unitPrice, unitPriceTax, amount, taxRate, orderNumber];

  bool get isEmpty => _values.every((v) => v.isEmpty);

  /// Each column by its key, as [toJson] names them.
  String operator [](String key) => _values[_keys.indexOf(key)];

  /// This with [key] set to [value].
  LedgerFields withValue(String key, String value) {
    final v = [..._values];
    v[_keys.indexOf(key)] = value;
    return LedgerFields(
      orderDate: v[0], deliveryDate: v[1], serial: v[2], supplier: v[3], unit: v[4], listPrice: v[5],
      unitPrice: v[6], unitPriceTax: v[7], amount: v[8], taxRate: v[9], orderNumber: v[10],
    );
  }

  Map<String, dynamic> toJson() => {
        for (final (i, k) in _keys.indexed)
          if (_values[i].isNotEmpty) k: _values[i],
      };

  factory LedgerFields.fromJson(Map<String, dynamic> j) {
    String s(String k) {
      final v = j[k];
      if (v == null) return '';
      if (v is double && v == v.roundToDouble()) return v.toInt().toString();
      return '$v'.trim();
    }

    return LedgerFields(
      orderDate: s('order_date'),
      deliveryDate: s('delivery_date'),
      serial: s('serial'),
      supplier: s('supplier'),
      unit: s('unit'),
      listPrice: s('list_price'),
      unitPrice: s('unit_price'),
      unitPriceTax: s('unit_price_tax'),
      amount: s('amount'),
      taxRate: s('tax_rate'),
      orderNumber: s('order_number'),
    );
  }

  /// 単価 (税込): as written, else 単価 (税抜) with the line's tax (10% when
  /// it names none), to the yen's hundredth.
  String get unitPriceWithTax {
    if (unitPriceTax.isNotEmpty) return unitPriceTax;
    final p = double.tryParse(unitPrice.replaceAll(RegExp(r'[,，\s¥円]'), ''));
    if (p == null) return '';
    var rate = double.tryParse(taxRate.replaceAll(RegExp(r'[%％\s]'), '')) ?? 0.1;
    if (rate >= 1) rate /= 100;
    final v = (p * (1 + rate) * 100).round() / 100;
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  @override
  List<Object?> get props => _values;
}

/// What a stock file holds: its lines, one per JAN, and the rows that could
/// not be read. [header] is false when no JAN and quantity columns were
/// found at all.
/// What a heading the app did not know means, as the server judged it
/// (0163): from the headings learned for the company, or by the AI from the
/// heading and a few rows. [field] is a reading field (document_fields:
/// product_name, product_code, maker, spec, …).
class HeadingMeaning extends Equatable {
  const HeadingMeaning({required this.index, required this.header, required this.field, this.source = 'ai'});

  final int index;
  final String header;
  final String field;

  /// ai, or partner / global / contains (a heading already learned).
  final String source;

  bool get byAi => source == 'ai';

  factory HeadingMeaning.fromJson(Map<String, dynamic> j) => HeadingMeaning(
        index: (j['index'] as num?)?.toInt() ?? -1,
        header: '${j['header'] ?? ''}',
        field: '${j['field'] ?? ''}',
        source: '${j['source'] ?? 'ai'}',
      );

  @override
  List<Object?> get props => [index, header, field, source];
}

/// A reading field → what a stock sheet keeps of it. 品名 and 品番 are what
/// each supplier calls the item; a cell holding both counts as its name.
const _stockFieldOf = <String, String>{
  'jan': 'jan',
  'quantity': 'qty',
  'product_name': 'name',
  'name_code': 'name',
  'maker': 'maker',
  'product_code': 'code',
  'order_date': 'order_date',
  'delivery_date': 'delivery_date',
  'serial': 'serial',
  'supplier': 'supplier',
  'unit': 'unit',
  'list_price': 'list_price',
  'unit_price': 'unit_price',
  'unit_price_tax': 'unit_price_tax',
  'amount': 'amount',
  'tax_rate': 'tax_rate',
  'order_number': 'order_number',
};

class StockSheet extends Equatable {
  const StockSheet({
    this.lines = const [],
    this.problems = const [],
    this.header = true,
    this.byAi = false,
    this.read = const [],
    this.headerRow = -1,
    this.headings = const [],
    this.unplaced = const [],
    this.meanings = const [],
  });

  final List<StockFileLine> lines;

  /// Every row as it was read, lines and problems alike.
  final List<ReadRow> read;
  final List<StockFileProblem> problems;
  final bool header;

  /// Read by the AI (a PDF, a picture, or a sheet without the headings),
  /// not cell by cell: its lines are to be checked by eye.
  final bool byAi;

  /// The heading row (0-based) of a sheet read here, and its cells.
  final int headerRow;
  final List<String> headings;

  /// Columns with a heading the app's own words did not place: for the
  /// server to judge (0163).
  final List<int> unplaced;

  /// What the server said those headings mean, used or not.
  final List<HeadingMeaning> meanings;

  /// The judged headings this reading took a column from.
  List<HeadingMeaning> get usedMeanings => [for (final m in meanings) if (_stockFieldOf.containsKey(m.field)) m];

  /// Judged, but nothing a stock reading keeps (規格, 入数, …).
  List<HeadingMeaning> get unusedMeanings => [for (final m in meanings) if (!_stockFieldOf.containsKey(m.field)) m];

  StockSheet copyWith({List<StockFileLine>? lines}) => StockSheet(
        lines: lines ?? this.lines,
        problems: problems,
        header: header,
        byAi: byAi,
        read: read,
        headerRow: headerRow,
        headings: headings,
        unplaced: unplaced,
        meanings: meanings,
      );

  @override
  List<Object?> get props => [lines, problems, header, byAi, read, headerRow, headings, unplaced, meanings];

  /// A few rows under the heading, for the server to judge the headings by.
  List<List<String>> samplesFrom(List<List<String>> rows) => [
        for (var r = headerRow + 1; r < rows.length; r++)
          if (rows[r].any((c) => c.trim().isNotEmpty)) rows[r],
      ].take(6).toList();
}

String _key(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s　_\-()（）・/]'), '');

const _janNames = {'jan', 'janコード', 'jancode', 'バーコード', 'barcode', 'ean', 'ean13', 'janno', 'ジャパンコード', 'japanコード'};
const _qtyNames = {'数量', '在庫数', '在庫', '個数', '入庫数', '実在庫', '実在庫数', 'qty', 'quantity', 'stock', 'onhand'};
const _nameNames = {'商品名', '品名', '名称', 'name', 'productname', 'itemname'};
const _makerNames = {'メーカー', 'メーカー名', 'maker', 'brand', 'manufacturer', '品牌', '厂家'};

/// A purchase ledger's (明細) other headings (0150), Japanese and Chinese.
const _ledgerNames = <String, Set<String>>{
  'order_date': {'発注日', '注文日', '下单时间', '下单日期', '订购日期'},
  'delivery_date': {'入荷日', '納品日', '着荷日', '到着日', '到货时间', '到货日期'},
  'serial': {'番号', '序番', '编号', '序号'},
  'supplier': {'仕入先', '仕入先名', '供給元', '供货商', '供应商'},
  'unit': {'単位', '单位'},
  'list_price': {'定価', '定価税抜', '上代', '零售价', '零售价税拔'},
  'unit_price': {'単価', '単価税抜', '税抜単価', '单价', '单价税前'},
  'unit_price_tax': {'単価税込', '税込単価', '单价税入', '单价含税'},
  'amount': {'金額', '合計', '金额', '合计'},
  'tax_rate': {'税率'},
  'order_number': {'注番', '注文番号', '注文no', '発注番号', 'オーダー番号', '订单号'},
};
const _codeNames = {'品番', '型番', '商品コード', 'sku', 'itemcode', 'productcode'};
const _aiJanNames = {'読み取ったjan', 'aiが読んだjan'};
const _aiQtyNames = {'読み取った数量', 'aiが読んだ数量'};

/// Reads the rows of a stock sheet: the first row (of the top ten) naming a
/// JAN column and a quantity column is the header. A JAN is any 8–14 digits
/// (full-width too) and is normalized as the scanner does; a quantity is a
/// whole number of 0 or more. The same JAN twice is one line, its
/// quantities summed.
///
/// [meanings] are headings the server judged (0163): each fills a column
/// the app's own words left empty (商品名称 → 品名, メーカー品番 → 品番).
StockSheet parseStockRows(List<List<String>> rows, {List<HeadingMeaning> meanings = const []}) {
  var head = -1, jan = -1, qty = -1, name = -1, makerCol = -1, codeCol = -1, aiJanCol = -1, aiQtyCol = -1;
  final ledgerCols = <String, int>{};
  for (var r = 0; r < rows.length && r < 10; r++) {
    final keys = [for (final c in rows[r]) _key(c)];
    final j = keys.indexWhere(_janNames.contains);
    final q = keys.indexWhere(_qtyNames.contains);
    if (j >= 0 && q >= 0) {
      head = r;
      jan = j;
      qty = q;
      name = keys.indexWhere(_nameNames.contains);
      makerCol = keys.indexWhere(_makerNames.contains);
      codeCol = keys.indexWhere(_codeNames.contains);
      aiJanCol = keys.indexWhere(_aiJanNames.contains);
      aiQtyCol = keys.indexWhere(_aiQtyNames.contains);
      for (final e in _ledgerNames.entries) {
        ledgerCols[e.key] = keys.indexWhere(e.value.contains);
      }
      break;
    }
  }
  if (head < 0) return const StockSheet(header: false);

  // The server's judgement fills only what the app's own words left empty.
  final used = <int>{jan, qty, name, makerCol, codeCol, aiJanCol, aiQtyCol, ...ledgerCols.values}..remove(-1);
  for (final m in meanings) {
    final f = _stockFieldOf[m.field];
    if (f == null || used.contains(m.index) || m.index < 0) continue;
    switch (f) {
      case 'name' when name < 0:
        name = m.index;
      case 'maker' when makerCol < 0:
        makerCol = m.index;
      case 'code' when codeCol < 0:
        codeCol = m.index;
      case 'jan' || 'qty' || 'name' || 'maker' || 'code':
        continue;
      default:
        if ((ledgerCols[f] ?? -1) >= 0) continue;
        ledgerCols[f] = m.index;
    }
    used.add(m.index);
  }
  final headings = [for (final c in rows[head]) c.trim()];
  final unplaced = [
    for (var c = 0; c < headings.length; c++)
      if (headings[c].isNotEmpty && !used.contains(c)) c,
  ];

  final byJan = <String, StockFileLine>{};
  final problems = <StockFileProblem>[];
  final read = <ReadRow>[];
  String at(List<String> row, int c) => c >= 0 && c < row.length ? row[c].trim() : '';
  String? opt(List<String> row, int c) => at(row, c).isEmpty ? null : at(row, c);
  for (var r = head + 1; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((c) => c.trim().isEmpty)) continue;
    final no = r + 1;
    final readRow = ReadRow(
      lineNo: no,
      jan: at(row, jan),
      name: at(row, name),
      quantity: at(row, qty),
      maker: at(row, makerCol),
      code: at(row, codeCol),
      aiJan: aiJanCol >= 0 ? at(row, aiJanCol) : null,
      aiQuantity: aiQtyCol >= 0 ? at(row, aiQtyCol) : null,
      ledger: LedgerFields.fromJson({for (final e in ledgerCols.entries) e.key: at(row, e.value)}),
    );
    read.add(readRow.corrected ? readRow.withFlags(const ['human_corrected']) : readRow);
    if (_notItem(at(row, jan), at(row, qty))) {
      problems.add(StockFileProblem(no, 'not_item', value: at(row, name)));
      continue;
    }
    final rawJan = at(row, jan);
    final code = normalizeJan(rawJan);
    if (code == null || code.length < 8 || code.length > 14) {
      problems.add(StockFileProblem(no, 'no_jan', value: rawJan));
      continue;
    }
    final rawQty = at(row, qty).replaceAll(RegExp(r'[,，\s]'), '');
    final q = int.tryParse(rawQty) ?? double.tryParse(rawQty)?.let((d) => d == d.roundToDouble() ? d.toInt() : null);
    if (q == null || q < 0) {
      problems.add(StockFileProblem(no, 'bad_quantity', value: at(row, qty)));
      continue;
    }
    final prev = byJan[code];
    byJan[code] = StockFileLine(
      lineNo: prev?.lineNo ?? no,
      janCode: code,
      quantity: (prev?.quantity ?? 0) + q,
      name: prev?.name ?? opt(row, name),
      merged: (prev?.merged ?? 0) + 1,
      maker: prev?.maker ?? opt(row, makerCol),
      code: prev?.code ?? opt(row, codeCol),
    );
  }
  return StockSheet(
    lines: byJan.values.toList(),
    problems: problems,
    read: read,
    headerRow: head,
    headings: headings,
    unplaced: unplaced,
    meanings: meanings,
  );
}

/// Whether the app reads [fileName] itself (a sheet or CSV); anything else
/// — a PDF, a scan, a photo, an old .xls — is read by the AI.
bool readsLocally(String fileName) {
  final lower = fileName.toLowerCase();
  return ['.xlsx', '.xlsm', '.csv', '.tsv', '.txt'].any(lower.endsWith);
}

/// A row with no digit of a JAN and no quantity is not a product: a branch
/// or an address the reader took for a line, a heading, a blank.
bool _notItem(String jan, String qty) =>
    (normalizeJan(jan) ?? '').isEmpty && qty.replaceAll(RegExp(r'[\s,，0]'), '').isEmpty;

/// A quantity too large to be one: more likely a JAN, a price or an amount
/// read into the wrong column. Asked about before it goes in.
bool implausibleQuantity(int q) => q >= 100000;

/// The file, by its bytes (CRC-32 and length): the same file chosen again.
String fileFingerprint(Uint8List bytes) => 'f:${getCrc32(bytes).toRadixString(16)}:${bytes.length}';

/// What goes in, by JAN and quantity in order: the same delivery read again,
/// or a corrected copy of it, comes to the same fingerprint.
String linesFingerprint(List<StockFileLine> lines) {
  final key = ([for (final l in lines) '${l.janCode}=${l.quantity}']..sort()).join(';');
  return 'l:${getCrc32(utf8.encode(key)).toRadixString(16)}:${lines.length}';
}

/// Flags that say something is missing, not that the reading is in doubt.
const _noDoubt = {'no_maker'};

/// Lines the AI read (import-plan, nothing booked) as a stock sheet: a JAN
/// and a quantity each, the same JAN summed, and the ones it could not be
/// sure of (any flag on the row) marked.
StockSheet stockSheetFromRead(List<ReadRow> rows, {bool byAi = true}) {
  final byJan = <String, StockFileLine>{};
  final problems = <StockFileProblem>[];
  for (final row in rows) {
    final no = row.lineNo;
    // Left out by hand: kept in the reading, not taken.
    if (row.humanRemoved) continue;
    if (_notItem(row.jan, row.quantity)) {
      problems.add(StockFileProblem(no, 'not_item', value: row.name));
      continue;
    }
    final code = normalizeJan(row.jan);
    if (code == null || code.length < 8 || code.length > 14) {
      problems.add(StockFileProblem(no, 'no_jan', value: row.jan.isEmpty ? row.name : row.jan));
      continue;
    }
    final t = row.quantity.replaceAll(RegExp(r'[,，\s]'), '');
    final d = double.tryParse(t);
    final q = int.tryParse(t) ?? (d != null && d == d.roundToDouble() ? d.toInt() : null);
    if (q == null || q < 0) {
      problems.add(StockFileProblem(no, 'bad_quantity', value: row.quantity.isEmpty ? '—' : row.quantity));
      continue;
    }
    final prev = byJan[code];
    byJan[code] = StockFileLine(
      lineNo: prev?.lineNo ?? no,
      janCode: code,
      quantity: (prev?.quantity ?? 0) + q,
      name: prev?.name ?? (row.name.isEmpty ? null : row.name),
      merged: (prev?.merged ?? 0) + 1,
      // Checked against the original by a person: no longer in doubt.
      doubtful: (prev?.doubtful ?? false) ||
          (!row.humanChecked && row.flags.any((f) => !_noDoubt.contains(f.split(':').first) && !humanFlags.contains(f))),
      maker: prev?.maker ?? (row.maker.isEmpty ? null : row.maker),
      code: prev?.code ?? (row.code.isEmpty ? null : row.code),
    );
  }
  return StockSheet(lines: byJan.values.toList(), problems: problems, byAi: byAi, read: rows);
}

/// A stock file's rows: an .xlsx's first sheet, or a UTF-8 CSV / TSV with
/// quoted cells. Throws [FormatException] for anything else.
List<List<String>> readStockFile(String fileName, Uint8List bytes) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.xlsx') || lower.endsWith('.xlsm')) return readXlsx(bytes);
  if (lower.endsWith('.csv') || lower.endsWith('.txt') || lower.endsWith('.tsv')) {
    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('﻿', '');
    return parseCsv(text, separator: lower.endsWith('.tsv') ? '\t' : ',');
  }
  throw const FormatException('not a stock sheet');
}

/// CSV rows: quoted cells may hold commas, newlines and doubled quotes.
List<List<String>> parseCsv(String text, {String separator = ','}) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == separator) {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

/// The 確認用Excel: every row of [sheet] as it was read, in the sheet this
/// screen reads — so a person can check it all, correct it, and choose the
/// corrected file to put in. Each row says what would become of it; cells to
/// look at (an unreadable JAN or quantity, a doubtful reading, an implausible
/// quantity) are yellow. The reading itself stays in 読み取ったJAN and
/// 読み取った数量, so what a person changed is known when it comes back.
Uint8List buildReviewXlsx({
  required String fileName,
  required StockSheet sheet,
  required Set<String> inLibrary,
  required Set<String> inPriceBook,
  required String Function(String flag) flagText,
}) {
  final problems = {for (final p in sheet.problems) p.lineNo: p.code};
  final rows = <List<Object?>>[];
  final flagged = <(int, int)>{};
  for (final r in sheet.read) {
    final jan = normalizeJan(r.jan);
    final validJan = jan != null && jan.length >= 8 && jan.length <= 14;
    final doubts = [for (final f in r.flags) if (!_noDoubt.contains(f.split(':').first) && !humanFlags.contains(f)) flagText(f)];
    final q = int.tryParse(r.quantity.replaceAll(RegExp(r'[,，\s]'), ''));
    final big = q != null && implausibleQuantity(q);
    final status = switch (problems[r.lineNo]) {
      'not_item' => '商品ではない行（無視します）',
      'no_jan' => 'JANが読めない（直してください）',
      'bad_quantity' => '数量が読めない（直してください）',
      _ when inLibrary.contains(jan) => '反映できる',
      _ when inPriceBook.contains(jan) => '価格台帳の名前で登録して反映',
      _ when r.name.trim().isNotEmpty || r.code.trim().isNotEmpty => '新しく登録して反映',
      _ => '商品名がなく登録できない',
    };
    final n = rows.length;
    if (problems[r.lineNo] == 'no_jan' || (doubts.isNotEmpty && problems[r.lineNo] != 'not_item')) flagged.add((n, 1));
    if (problems[r.lineNo] == 'bad_quantity' || big || (doubts.isNotEmpty && problems[r.lineNo] != 'not_item')) {
      flagged.add((n, 5));
    }
    rows.add([
      r.lineNo,
      validJan ? jan : r.jan,
      r.name,
      r.maker,
      r.code,
      q ?? r.quantity,
      [status, if (doubts.isNotEmpty) '要確認', if (big) '数量が大きすぎる'].join('・'),
      doubts.join(' / '),
      r.aiJan ?? r.jan,
      r.aiQuantity ?? r.quantity,
    ]);
  }
  return buildXlsx(
    sheetName: '在庫登録',
    top: [
      ['在庫登録 確認用（$fileName の読み取り）'],
      ['JANコード・商品名・数量を確かめて直し、保存したこのファイルを「ファイルから在庫登録」で選んでください。黄色は確かめてほしい欄です。'],
      [],
    ],
    headers: const ['元の行', 'JANコード', '商品名', 'メーカー', '品番', '数量', '状態', 'AIの迷い', '読み取ったJAN', '読み取った数量'],
    rows: rows,
    flagged: flagged,
    widths: const [8, 18, 40, 18, 16, 10, 30, 40, 18, 12],
  );
}

/// The sheet to fill in: JAN, 商品名 (for the reader's eye only) and 数量.
Uint8List stockTemplateXlsx() => buildXlsx(
      sheetName: '在庫登録',
      headers: const ['JANコード', '商品名', '数量'],
      rows: const [],
      widths: const [18, 40, 10],
    );

/// What the server did with a stock file.
class StockFileResult extends Equatable {
  const StockFileResult(
      {required this.importId, required this.lines, required this.change, this.skipped = const [], this.awaiting});

  final int importId;
  final int lines;

  /// The total change in units (negative when [StockFileMode.set] lowered it).
  final int change;
  final List<String> skipped;

  /// The units kept for inspection (0148), when the file was staged rather
  /// than booked; null when it went straight into stock.
  final int? awaiting;

  bool get staged => awaiting != null;

  factory StockFileResult.fromJson(Map<String, dynamic> j) => StockFileResult(
        importId: (j['import_id'] as num?)?.toInt() ?? 0,
        lines: (j['lines'] as num?)?.toInt() ?? 0,
        change: (j['change'] as num?)?.toInt() ?? 0,
        skipped: [
          for (final s in (j['skipped'] as List? ?? const []).whereType<Map>()) '${s['jan_code'] ?? ''}',
        ],
        awaiting: (j['awaiting'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props => [importId, lines, change, skipped, awaiting];
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
