import 'dart:typed_data';

import '../../../core/export/xlsx.dart';
import '../../outbound_file/domain/outbound_sheet.dart'
    show OutboundColumn, OutboundRow, normalizeOutboundJan, outboundHeadingKey, parseOutboundSheet, pickOutboundSheet;
import 'packing.dart';

/// What a column of a packing list holds. The wire names are those of the
/// `packing-list` function (0192).
enum PlField {
  cartonNo('carton_no'),
  cartonCount('carton_count'),
  description('description'),
  maker('maker'),
  itemCode('item_code'),
  jan('jan'),
  quantity('quantity'),
  size('size'),
  length('length'),
  width('width'),
  height('height'),
  cartonWeight('carton_weight'),
  netWeight('net_weight'),
  note('note');

  const PlField(this.wire);
  final String wire;

  static PlField? fromWire(String? w) {
    for (final f in values) {
      if (f.wire == w) return f;
    }
    return null;
  }
}

// Exact headings (as outboundHeadingKey leaves them), in Japanese, Chinese
// and English.
const _exact = <PlField, Set<String>>{
  PlField.cartonNo: {
    '箱番号', '箱番', '箱号', '箱號', '箱no', 'cno', 'cn', 'ctnno', 'ctn', 'cartonno', 'carton', 'boxno', 'box',
    'ケース番号', 'ケースno', '梱包番号', '梱包no', '件号', 'no', '番号', 'カートン番号', 'カートンno', 'packageno', 'pkgno',
  },
  PlField.cartonCount: {
    '箱量', '箱数', 'ケース数', 'カートン数', '件数', 'ctns', 'cartons', 'ofcartons', 'noofcartons', 'qtyofcartons', 'boxes',
    '箱数量',
  },
  PlField.description: {
    '品名', '商品名', '名称', '货名', '品名称', '产品名称', '產品名稱', '商品名称', 'description', 'descriptionofgoods', 'goods',
    'itemname', 'productname', '品目', '内容', '内容物', 'contents',
  },
  PlField.maker: {'メーカー', 'maker', 'brand', 'ブランド', '品牌', '厂家', '廠家', '厂商', 'manufacturer', '制造商', 'メーカー名'},
  PlField.itemCode: {
    '品番', '型番', '货号', '貨號', '型号', '型號', 'itemno', 'itemcode', 'partno', 'model', 'modelno', 'code', 'sku', '商品コード',
    '品番号', '规格型号', 'artno', 'articleno', 'styleno', '款号',
  },
  PlField.jan: {'jan', 'janコード', 'jancode', 'ean', 'eancode', 'barcode', '条码', '條碼', '条形码', 'バーコード', 'upc'},
  PlField.quantity: {'数量', 'qty', 'quantity', '个数', '個数', '入数', 'pcs', 'qtypcs', '数量pcs', '件数量', '数'},
  PlField.size: {
    'サイズ', 'size', '尺寸', '外箱尺寸', '箱尺寸', 'measurement', 'measurementcm', 'meas', '寸法', 'dimension', 'dimensions',
    '箱规', '箱規', 'サイズcm', 'sizecm', '尺寸cm', 'lwh', 'lxwxh', '縦横高さ', '长宽高', '長寬高',
  },
  PlField.length: {'縦', '長さ', '长', '長', 'length', 'l', 'lcm', '縦cm', '长cm', 'length cm'},
  PlField.width: {'横', '幅', '宽', '寬', 'width', 'w', 'wcm', '横cm', '宽cm'},
  PlField.height: {'高さ', '高', 'height', 'h', 'hcm', '高さcm', '高cm'},
  PlField.cartonWeight: {
    '单箱重量', '單箱重量', '箱重量', '毛重', 'gw', 'grossweight', 'gwkg', '総重量', '総重量kg', '重量', 'weight', 'weightkg', '重量kg',
    '单箱重量kg', '毛重kg', 'ケース重量', 'カートン重量', '箱の重さ', '重さ',
  },
  PlField.netWeight: {'分重量', '按数量分重量', '净重', '淨重', 'nw', 'netweight', 'nwkg', '正味重量', '正味', '分重量kg', '按数量分重量kg', '净重kg'},
  PlField.note: {'备注', '備註', '備考', 'note', 'notes', 'remark', 'remarks', 'メモ', '摘要', 'comment'},
};

bool _total(String k) => RegExp(r'汇总|彙總|合计|合計|总计|總計|小计|小計|total|sum|subtotal').hasMatch(k);

// A cell that starts a total row: 合計, 总计, TOTAL …
bool _totalCell(String k) => RegExp(r'^(汇总|彙總|合计|合計|总计|總計|小计|小計|total|subtotal|grandtotal)').hasMatch(k);

/// What a packing list heading means, by its words; null when they do not say.
PlField? guessPlField(String heading) {
  final k = outboundHeadingKey(heading);
  if (k.isEmpty || _total(k)) return null;
  for (final e in _exact.entries) {
    if (e.value.contains(k)) return e.key;
  }
  bool has(List<String> words) => words.any(k.contains);
  if (has(['分重量', '净重', '淨重', '正味', 'netweight', 'nw'])) return PlField.netWeight;
  if (has(['重量', 'weight', '毛重', 'gw', '重さ'])) return PlField.cartonWeight;
  if (has(['jan', 'ean', 'barcode', '条码', '條碼', 'バーコード'])) return PlField.jan;
  if (has(['箱番', '箱号', '箱號', 'cno', 'ctnno', 'cartonno', 'boxno', 'ケース番号', '梱包番号'])) return PlField.cartonNo;
  if (has(['箱量', '箱数', 'ケース数', 'ctns'])) return PlField.cartonCount;
  if (has(['サイズ', 'size', '尺寸', 'measurement', '寸法', 'dimension'])) return PlField.size;
  if (has(['品番', '型番', '货号', '型号', 'itemno', 'partno', 'model', 'sku', 'code'])) return PlField.itemCode;
  if (has(['メーカー', 'maker', 'brand', '品牌', '厂家', 'manufacturer'])) return PlField.maker;
  if (has(['品名', '商品名', '名称', 'description', 'goods'])) return PlField.description;
  if (has(['数量', 'qty', 'quantity', '個数', '个数', 'pcs'])) return PlField.quantity;
  if (has(['备注', '備考', 'remark', 'note'])) return PlField.note;
  return null;
}

/// Each column's meaning, the first column for a meaning winning.
Map<int, PlField> guessPlColumns(List<String> headers) {
  final out = <int, PlField>{};
  for (final (i, h) in headers.indexed) {
    final f = guessPlField(h);
    if (f != null && !out.values.contains(f)) out[i] = f;
  }
  return out;
}

bool _readable(Map<int, PlField> c) {
  final f = c.values.toSet();
  return f.contains(PlField.cartonNo) &&
      (f.contains(PlField.itemCode) || f.contains(PlField.jan) || f.contains(PlField.description));
}

/// The mark a sheet's boxes are numbered under, from its name: HL from
/// "PL-HL", '' from "Sheet4" or "パッキングリスト".
String plMarkOfSheet(String name) {
  for (final t in name.split(RegExp(r'[\s\-_・/()（）\[\]]+'))) {
    final u = t.toUpperCase();
    if (u.isEmpty || const {'PL', 'PACKING', 'LIST', 'PACKINGLIST', 'P'}.contains(u)) continue;
    if (RegExp(r'^SHEET\d*$').hasMatch(u)) continue;
    if (RegExp(r'^[A-Z]{1,4}\d*$').hasMatch(u)) return RegExp(r'^[A-Z]+').firstMatch(u)!.group(0)!;
  }
  return '';
}

bool _looksLikePl(String name) =>
    RegExp(r'pl|packing|装箱|裝箱|パッキング|箱|梱包|carton', caseSensitive: false).hasMatch(name);

/// A sheet of a workbook, read for a packing list: where its heading row is
/// and what each column means.
class PlSheet {
  const PlSheet({required this.name, required this.rows, required this.headerAt, required this.columns, required this.mark});

  final String name;
  final List<List<String>> rows;
  final int headerAt;
  final Map<int, PlField> columns;
  final String mark;

  List<String> get headers => headerAt < rows.length ? rows[headerAt] : const [];

  /// A few rows under the heading, for the AI to look at.
  List<List<String>> get samples => [
        for (final r in rows.skip(headerAt + 1))
          if (r.any((c) => c.isNotEmpty)) r,
      ].take(6).toList();

  bool get readable => _readable(columns);

  /// Worth asking the AI about: named like a packing list, or with a box
  /// number heading it did not read the rest of.
  bool get worthAsking =>
      !readable &&
      !const {'BOXES', 'BOX_TYPES', 'SUMMARY'}.contains(name) && // the sheets of our own list
      headers.any((h) => h.isNotEmpty) &&
      (_looksLikePl(name) || columns.values.contains(PlField.cartonNo));

  PlSheet withColumns(Map<int, PlField> c) => PlSheet(name: name, rows: rows, headerAt: headerAt, columns: c, mark: mark);
}

/// Each sheet with its best heading row (of the first 15): the one whose
/// words name the most columns.
List<PlSheet> guessPlSheets(List<XlsxSheetRows> sheets) {
  final out = <PlSheet>[];
  for (final s in sheets) {
    var at = -1;
    var best = <int, PlField>{};
    var widest = 0;
    var widestAt = 0;
    for (var r = 0; r < s.rows.length && r < 15; r++) {
      final c = guessPlColumns(s.rows[r]);
      if (c.length > best.length || (c.length == best.length && _readable(c) && !_readable(best))) {
        best = c;
        at = r;
      }
      final filled = s.rows[r].where((x) => x.isNotEmpty).length;
      if (filled > widest) {
        widest = filled;
        widestAt = r;
      }
    }
    if (best.length < 2) {
      at = widestAt;
      best = at < s.rows.length ? guessPlColumns(s.rows[at]) : {};
    }
    if (s.rows.isEmpty) continue;
    out.add(PlSheet(name: s.name, rows: s.rows, headerAt: at < 0 ? 0 : at, columns: best, mark: plMarkOfSheet(s.name)));
  }
  return out;
}

double? _num(String s) {
  final b = StringBuffer();
  for (final c in s.trim().runes) {
    b.writeCharCode(c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : c);
  }
  final m = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(b.toString().replaceAll(',', ''));
  return m == null ? null : double.tryParse(m.group(0)!);
}

/// "36 × 32 × 30", "54*38.5*34.5", "36x32x30cm" → (36, 32, 30).
(double, double, double)? parsePlSize(String s) {
  final b = StringBuffer();
  for (final c in s.runes) {
    b.writeCharCode(c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : c);
  }
  final n = [for (final m in RegExp(r'\d+(?:\.\d+)?').allMatches(b.toString())) double.parse(m.group(0)!)];
  if (n.length < 3) return null;
  final mm = RegExp(r'mm', caseSensitive: false).hasMatch(s);
  return mm ? (n[0] / 10, n[1] / 10, n[2] / 10) : (n[0], n[1], n[2]);
}

/// A box number cell: 12 → (12, 12); "12-15" or "12~15" → (12, 15).
(int, int)? _boxRange(String s) {
  final b = StringBuffer();
  for (final c in s.runes) {
    b.writeCharCode(c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : c);
  }
  final t = b.toString();
  final r = RegExp(r'(\d+)\s*[-~〜～—–]\s*(\d+)').firstMatch(t);
  if (r != null) {
    final a = int.parse(r.group(1)!), z = int.parse(r.group(2)!);
    if (z >= a && z - a < 1000) return (a, z);
  }
  final m = RegExp(r'\d+').firstMatch(t);
  if (m == null) return null;
  final v = int.parse(m.group(0)!);
  return (v, v);
}

double _r3(double v) => (v * 1000).roundToDouble() / 1000;

/// The boxes of one sheet. A row with a box number opens a box; a row
/// without one is more of the box above (as merged cells leave it). A box's
/// size and weight are taken from whichever of its rows has them. 箱量 (or a
/// range like 12-15) over 1 makes that many boxes alike, each holding the
/// row's quantity. Total rows and numbered rows with nothing in them are
/// passed over.
List<PackBox> readPlSheet(PlSheet s) {
  int? col(PlField f) {
    for (final e in s.columns.entries) {
      if (e.value == f) return e.key;
    }
    return null;
  }

  final cNo = col(PlField.cartonNo), cCount = col(PlField.cartonCount), cDesc = col(PlField.description);
  final cMaker = col(PlField.maker), cCode = col(PlField.itemCode), cJan = col(PlField.jan), cQty = col(PlField.quantity);
  final cSize = col(PlField.size), cL = col(PlField.length), cW = col(PlField.width), cH = col(PlField.height);
  final cGw = col(PlField.cartonWeight), cNw = col(PlField.netWeight), cNote = col(PlField.note);
  String at(List<String> r, int? c) => c == null || c >= r.length ? '' : r[c].trim();
  // Only the columns read count: a side summary (品名汇总 …) is not a row.
  final read = s.columns.keys.toSet();

  final out = <PackBox>[];
  // The box being read, as parts: number range, size, weights, items, notes.
  (int, int)? range;
  var boxMark = s.mark;
  double? l, w, h, gw, nw;
  var items = <PackItem>[];
  var notes = <String>[];
  var anyNet = false;

  void close() {
    final rg = range;
    if (rg == null || items.isEmpty) {
      range = null;
      return;
    }
    final n = rg.$2 - rg.$1 + 1;
    final weight = gw ?? (anyNet ? _r3(nw ?? 0) : null);
    for (var k = 0; k < n; k++) {
      out.add(PackBox(
        boxNo: rg.$1 + k,
        mark: boxMark.isEmpty ? null : boxMark,
        lengthCm: l,
        widthCm: w,
        heightCm: h,
        grossKg: weight,
        note: notes.isEmpty ? null : notes.join(' / '),
        items: items,
      ));
    }
    range = null;
  }

  for (final r in s.rows.skip(s.headerAt + 1)) {
    final cells = [for (final c in read) at(r, c)];
    if (cells.every((c) => c.isEmpty)) continue;
    if (cells.any((c) => _totalCell(outboundHeadingKey(c)))) continue;
    final no = at(r, cNo);
    final desc = at(r, cDesc), maker = at(r, cMaker), code = at(r, cCode), jan = normalizeOutboundJan(at(r, cJan));
    final qty = _num(at(r, cQty));
    final hasItem = desc.isNotEmpty || code.isNotEmpty || jan.isNotEmpty || (qty != null && qty > 0);
    if (no.isNotEmpty) {
      final rg = _boxRange(no);
      final m = RegExp(r'^([A-Za-z]{1,6})\s*[-‐ー－]?\s*\d').firstMatch(no)?.group(1)?.toUpperCase();
      // The same number again (as our own list writes it on every row) is
      // more of the same box.
      final same = rg != null && range != null && rg.$1 == range!.$1 && (m ?? s.mark) == boxMark;
      if (rg != null && !same) {
        close();
        boxMark = m ?? s.mark;
        if (!hasItem) continue;
        var rgv = rg;
        final count = _num(at(r, cCount))?.toInt() ?? 1;
        if (rg.$1 == rg.$2 && count > 1) rgv = (rg.$1, rg.$1 + count - 1);
        range = rgv;
        l = w = h = gw = nw = null;
        items = [];
        notes = [];
        anyNet = false;
      }
    }
    if (range == null || !hasItem) continue;
    final size = parsePlSize(at(r, cSize));
    if (l == null && size != null) (l, w, h) = size;
    l ??= _num(at(r, cL));
    w ??= _num(at(r, cW));
    h ??= _num(at(r, cH));
    gw ??= _num(at(r, cGw));
    final net = _num(at(r, cNw));
    if (net != null) {
      nw = (nw ?? 0) + net;
      anyNet = true;
    }
    final note = at(r, cNote);
    if (note.isNotEmpty && !notes.contains(note)) notes.add(note);
    items = [
      ...items,
      PackItem(
        jan: jan.isEmpty ? null : jan,
        code: code.isEmpty ? null : code,
        name: desc.isEmpty ? null : desc,
        maker: maker.isEmpty ? null : maker,
        quantity: qty?.round() ?? 0,
      ),
    ];
  }
  close();
  return out;
}

/// A packing list read from a workbook.
class PackingListRead {
  const PackingListRead({
    required this.sheets,
    required this.boxes,
    this.askedAi = const [],
    this.detail = const [],
    this.detailSheet,
  });

  /// The 明細 beside it (the shipping list's rows, with prices), if the
  /// workbook has one.
  final List<OutboundRow> detail;
  final String? detailSheet;

  /// The sheets read, each with its boxes.
  final List<PlSheet> sheets;
  final List<PackBox> boxes;

  /// Sheets whose columns the AI named.
  final List<String> askedAi;

  int get quantity => boxes.fold(0, (a, b) => a + b.quantity);

  double get grossKg => boxes.fold(0.0, (a, b) => a + (b.weightKg ?? 0));

  double get cbm => boxes.fold(0.0, (a, b) => a + (b.volumeM3 ?? 0));

  /// More than one mark, so box numbers need theirs (HL-3).
  bool get marked => boxes.map((b) => b.mark ?? '').toSet().length > 1;
}

String _codeKey(String s) => s.replaceAll(RegExp(r'[\s\-_.・/]'), '').toUpperCase();

/// JANs by 品番 from the other sheets of the workbook (a 明细 sheet):
/// a JAN under the same mark (注番 BL …) first.
Map<String, String> _jansByCode(List<XlsxSheetRows> sheets, Set<String> plSheets) {
  final out = <String, String>{};
  for (final s in sheets) {
    if (plSheets.contains(s.name)) continue;
    final read = parseOutboundSheet(s.name, s.rows);
    for (final r in read.rows) {
      if (r.jan.isEmpty || r.code == null) continue;
      final k = _codeKey(r.code!);
      final m = packMarkOf(r.orderNumber);
      out.putIfAbsent('$m|$k', () => r.jan);
      out.putIfAbsent('|$k', () => r.jan);
    }
  }
  return out;
}

/// [boxes] with the JANs their 品番 have in [jans] where they have none.
List<PackBox> _fillJans(List<PackBox> boxes, Map<String, String> jans) {
  if (jans.isEmpty) return boxes;
  return [
    for (final b in boxes)
      b.copyWith(items: [
        for (final i in b.items)
          if (i.jan == null && i.code != null)
            i.copyWith(jan: jans['${b.mark ?? ''}|${_codeKey(i.code!)}'] ?? jans['|${_codeKey(i.code!)}'])
          else
            i,
      ]),
  ];
}

/// Asks the AI what each column means: (headers, samples) → columns.
typedef PlColumnsAsker = Future<Map<int, PlField>> Function(List<String> headers, List<List<String>> samples);

/// The packing list in [bytes]: every sheet that reads as one (the AI asked
/// about those whose headings do not say), its boxes in sheet order, JANs
/// filled in by 品番 from a 明细 sheet beside it. Two
/// sheets with the same mark get their sheet names as marks so their
/// numbers do not run into each other.
Future<PackingListRead> readPackingList(Uint8List bytes, {PlColumnsAsker? ask}) async {
  final book = readXlsxSheets(bytes);
  final all = guessPlSheets(book);
  final used = <PlSheet>[];
  final asked = <String>[];
  for (var s in all) {
    if (!s.readable && s.worthAsking && ask != null) {
      try {
        final c = await ask(s.headers, s.samples);
        if (c.isNotEmpty) {
          s = s.withColumns(c);
          asked.add(s.name);
        }
      } catch (_) {
        // Read without it.
      }
    }
    if (s.readable) used.add(s);
  }
  final marks = <String, int>{};
  for (final s in used) {
    marks[s.mark] = (marks[s.mark] ?? 0) + 1;
  }
  final boxes = <PackBox>[];
  final sheets = <PlSheet>[];
  for (final s in used) {
    final named = marks[s.mark]! > 1 && used.length > 1
        ? PlSheet(name: s.name, rows: s.rows, headerAt: s.headerAt, columns: s.columns, mark: s.name)
        : s;
    final b = readPlSheet(named);
    if (b.isEmpty) continue;
    sheets.add(named);
    boxes.addAll(b);
  }
  var filled = boxes;
  try {
    filled = _fillJans(boxes, _jansByCode(book, {for (final s in sheets) s.name}));
  } catch (_) {
    // A sheet that does not read as a list gives no JANs.
  }
  final detail = _detailOf(book, {for (final s in sheets) s.name});
  return PackingListRead(
    sheets: sheets,
    boxes: filled,
    askedAi: asked,
    detail: detail?.rows ?? const [],
    detailSheet: detail?.name,
  );
}

/// The 明細 of the workbook: of the sheets not read as a packing list (nor
/// our own BOXES …), the one that reads best as a shipping list — a quantity
/// and a JAN or 品番 — if any does.
({String name, List<OutboundRow> rows})? _detailOf(List<XlsxSheetRows> book, Set<String> plSheets) {
  try {
    final rest = [
      for (final s in book)
        if (!plSheets.contains(s.name) && !const {'PACKING LIST', 'BOXES', 'BOX_TYPES', 'SUMMARY'}.contains(s.name)) s,
    ];
    if (rest.isEmpty) return null;
    final s = rest[pickOutboundSheet(rest)];
    final p = parseOutboundSheet(s.name, s.rows);
    final c = p.columns;
    if (!c.containsKey(OutboundColumn.quantity) || !(c.containsKey(OutboundColumn.jan) || c.containsKey(OutboundColumn.code))) {
      return null;
    }
    final rows = [for (final r in p.rows) if ((r.quantity ?? 0) > 0 && (r.jan.isNotEmpty || r.code != null)) r];
    return rows.isEmpty ? null : (name: s.name, rows: rows);
  } catch (_) {
    return null;
  }
}

/// What the boxes teach about each product's own case: a box that holds one
/// product, of a size and weight, says how many fit in its case. By JAN,
/// else 品番: (jan, code, maker, quantity, l, w, h, kg), the commonest
/// quantity for each.
List<({String? jan, String? code, String? maker, int quantity, double? l, double? w, double? h, double? kg})> learnCasePacks(
    List<PackBox> boxes) {
  final seen = <String, Map<int, List<PackBox>>>{};
  for (final b in boxes) {
    if (b.items.length != 1) continue;
    final i = b.items.single;
    if (i.quantity <= 0) continue;
    final k = i.jan != null ? 'j${i.jan}' : (i.code != null ? 'c${i.code}|${i.maker ?? ''}' : null);
    if (k == null) continue;
    ((seen[k] ??= {})[i.quantity] ??= []).add(b);
  }
  return [
    for (final byQty in seen.values)
      () {
        final best = byQty.entries.reduce((a, c) => c.value.length > a.value.length ? c : a);
        final b = best.value.firstWhere((x) => x.lengthCm != null, orElse: () => best.value.first);
        final i = b.items.single;
        return (jan: i.jan, code: i.code, maker: i.maker, quantity: best.key, l: b.lengthCm, w: b.widthCm, h: b.heightCm, kg: b.grossKg);
      }(),
  ];
}
