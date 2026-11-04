import 'dart:convert';
import 'dart:typed_data';

import '../../../core/export/xlsx.dart';
import '../../outbound/domain/outbound.dart' show ShipDestination;
import '../../shipment/domain/packaging.dart' show CartonType;
import '../domain/packing.dart';

/// The heading of a packing list: who sends, who receives, the papers'
/// numbers. What is not known is left as a hint to fill in.
class PlHeader {
  const PlHeader({
    this.shipper,
    this.consignee,
    this.notifyParty,
    this.invoiceNo,
    this.date,
    this.ports,
    this.marks,
  });

  /// From a 出荷先カード: its name, address, telephone and tax number.
  factory PlHeader.fromDestination(ShipDestination? d, {String? shipper, String? date, String? invoiceNo, String? marks}) {
    if (d == null) return PlHeader(shipper: shipper, date: date, invoiceNo: invoiceNo, marks: marks);
    final consignee = [
      d.nameEn ?? d.name,
      d.addressEn ?? d.addressLine,
      if (d.countryCode != null) d.countryCode!,
      for (final p in d.allPhones) 'Tel: $p',
      if (d.taxId != null) '${d.taxIdKind ?? 'Tax ID'}: ${d.taxId}',
    ].where((s) => s.trim().isNotEmpty).join(', ');
    final notify = d.notifySame || d.notifyName == null
        ? 'SAME AS CONSIGNEE'
        : [d.notifyName!, if (d.notifyAddress != null) d.notifyAddress!, if (d.notifyPhone != null) 'Tel: ${d.notifyPhone}'].join(', ');
    return PlHeader(
      shipper: shipper,
      consignee: consignee,
      notifyParty: notify,
      invoiceNo: invoiceNo,
      date: date,
      ports: d.port == null ? null : 'JAPAN / ${d.port}',
      marks: marks,
    );
  }

  final String? shipper;
  final String? consignee;
  final String? notifyParty;
  final String? invoiceNo;
  final String? date;
  final String? ports;
  final String? marks;

  List<(String, String)> get lines => [
        ('Shipper', shipper ?? '（自社名・住所・電話）'),
        ('Consignee', consignee ?? '（出荷先カードから: 会社名・住所・Tel・Tax ID）'),
        ('Notify Party', notifyParty ?? 'SAME AS CONSIGNEE'),
        ('Invoice No.', invoiceNo ?? '（インボイス番号）'),
        ('Date', date ?? '（出荷日）'),
        ('Port of Loading / Destination', ports ?? '（積出港 / 仕向け港）'),
        ('Shipping Marks', marks ?? ''),
      ];
}

double _r4(double v) => (v * 10000).roundToDouble() / 10000;
double _r3(double v) => (v * 1000).roundToDouble() / 1000;

String _n(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// The box types a list's boxes are in: ours by name (S, M, L), the rest
/// by size — T1, T2 … one for each size — so a box's size is written once.
class PlBoxTypes {
  PlBoxTypes(List<PackBox> boxes, {List<CartonType> cartons = const []}) {
    String? match(PackBox b) {
      for (final c in cartons) {
        if (c.lengthCm == b.lengthCm && c.widthCm == b.widthCm && c.heightCm == b.heightCm) return c.name;
      }
      return null;
    }

    for (final b in boxes) {
      if (b.lengthCm == null || b.widthCm == null || b.heightCm == null) {
        of.add(null);
        continue;
      }
      final dims = (b.lengthCm!, b.widthCm!, b.heightCm!);
      final named = b.ownCase ? null : (b.cartonType ?? match(b));
      var t = types.where((x) => x.dims == dims && (named == null || x.name == named)).firstOrNull;
      if (t == null) {
        var name = named ?? 'T${types.where((x) => x.name.startsWith('T')).length + 1}';
        while (types.any((x) => x.name == name)) {
          name = '$name*';
        }
        final ours = cartons.where((c) => c.name == named).firstOrNull;
        t = (
          name: name,
          dims: dims,
          tareKg: ours == null ? b.tareKg : (ours.emptyWeightG + ours.packingMaterialG) / 1000,
          memo: named != null ? '自社の箱' : (b.ownCase ? 'メーカーの元箱' : '元の表記から（自社の箱なら名前を S/M/L などに）'),
        );
        types.add(t);
      }
      of.add(t.name);
    }
  }

  final types = <({String name, (double, double, double) dims, double? tareKg, String memo})>[];

  /// Each box's type, in order (null: no size).
  final of = <String?>[];

  ({String name, (double, double, double) dims, double? tareKg, String memo})? byName(String? n) =>
      n == null ? null : types.where((t) => t.name == n).firstOrNull;
}

/// The improved packing list (パッキングリスト_改善案): one sheet to send —
/// a row for each product in each box, the box number on every row and the
/// box's type, size, weight and m³ on its first, worked out from BOXES —
/// then BOXES (one row a box: type from a list, size from the type, weight),
/// BOX_TYPES (the few boxes used) and SUMMARY (each product: how many, in
/// how many boxes). JANs not known are filled yellow.
Uint8List buildPackingListXlsx(List<PackBox> boxes, {PlHeader header = const PlHeader(), List<CartonType> cartons = const []}) {
  final marked = boxes.map((b) => b.mark ?? '').toSet().length > 1;
  Object key(PackBox b) => marked ? b.label : b.boxNo;
  final types = PlBoxTypes(boxes, cartons: cartons);

  // PACKING LIST.
  final top = <List<Object?>>[
    ['PACKING LIST'],
    [],
    for (final (k, v) in header.lines) [k, null, v],
    [],
  ];
  final first = top.length + 2; // the first row of lines, 1-based
  final rows = <List<Object?>>[];
  final flagged = <(int, int)>{};
  for (final (bi, b) in boxes.indexed) {
    final items = b.items.isEmpty ? const [PackItem(quantity: 0)] : b.items;
    final type = types.byName(types.of[bi]);
    final vol = b.volumeM3;
    for (final (ii, it) in items.indexed) {
      final n = first + rows.length;
      final lead = ii == 0;
      String look(int c) => 'VLOOKUP(\$A$n,BOXES!\$A:\$I,$c,FALSE)';
      if (it.jan == null) flagged.add((rows.length, 4));
      rows.add([
        key(b),
        it.name ?? '',
        it.maker ?? '',
        it.code ?? '',
        it.jan ?? '',
        it.quantity,
        XlsxFormula('IF(A$n<>A${n - 1},${look(2)}&"","")', cached: lead ? (types.of[bi] ?? '') : ''),
        XlsxFormula('IF(A$n<>A${n - 1},IF(${look(3)}="","",${look(3)}&" x "&${look(4)}&" x "&${look(5)}),"")',
            cached: lead && type != null ? '${_n(type.dims.$1)} x ${_n(type.dims.$2)} x ${_n(type.dims.$3)}' : ''),
        XlsxFormula('IF(A$n<>A${n - 1},IF(${look(7)}="","",${look(7)}),"")',
            cached: lead && b.weightKg != null ? _r3(b.weightKg!) : ''),
        XlsxFormula('IF(A$n<>A${n - 1},${look(6)},"")', cached: lead && vol != null && type != null ? _r4(vol) : ''),
      ]);
    }
  }
  final last = first + rows.length - 1;
  final nb = boxes.length;
  final qty = boxes.fold(0, (a, b) => a + b.quantity);
  final kg = boxes.fold(0.0, (a, b) => a + (b.weightKg ?? 0));
  final cbm = [for (final (i, b) in boxes.indexed) if (types.of[i] != null) _r4(b.volumeM3 ?? 0)].fold(0.0, (a, v) => a + v);
  final bottom = <List<Object?>>[
    [],
    ['Total cartons 箱数', null, null, null, null, XlsxFormula('COUNTA(BOXES!A2:A${nb + 1})', cached: nb)],
    ["Total Q'ty 総数量", null, null, null, null, XlsxFormula('SUM(F$first:F$last)', cached: qty)],
    ['Total G.W. (kg) 総重量', null, null, null, null, XlsxFormula('SUM(BOXES!G2:G${nb + 1})', cached: _r3(kg))],
    ['Total CBM 総容積', null, null, null, null, XlsxFormula('SUM(BOXES!F2:F${nb + 1})', cached: _r4(cbm))],
  ];
  final list = XlsxSheet(
    name: 'PACKING LIST',
    top: top,
    headers: const [
      'C/No. 箱番号', 'Description 品名', 'Maker メーカー', 'Item No. 品番', 'JAN', "Q'ty 数量", 'Box type 箱種',
      'Measurement サイズ (cm)', 'G.W. (kg) 箱の総重量', 'CBM 容積 (m³)',
    ],
    rows: rows,
    flagged: flagged,
    bottom: bottom,
    widths: const [10, 24, 16, 18, 15, 9, 9, 18, 12, 10],
  );

  // BOXES.
  final boxRows = <List<Object?>>[];
  for (final (i, b) in boxes.indexed) {
    final r = i + 2;
    final t = types.byName(types.of[i]);
    String look(int c) => 'IFERROR(VLOOKUP(\$B$r,BOX_TYPES!\$A:\$E,$c,FALSE),"")';
    boxRows.add([
      key(b),
      types.of[i] ?? '',
      XlsxFormula(look(2), cached: t?.dims.$1 ?? ''),
      XlsxFormula(look(3), cached: t?.dims.$2 ?? ''),
      XlsxFormula(look(4), cached: t?.dims.$3 ?? ''),
      XlsxFormula('IFERROR(ROUND(C$r*D$r*E$r/1000000,4),"")', cached: t == null ? '' : _r4(t.dims.$1 * t.dims.$2 * t.dims.$3 / 1000000)),
      b.weightKg == null ? null : _r3(b.weightKg!),
      XlsxFormula("COUNTIF('PACKING LIST'!\$A:\$A,A$r)", cached: b.items.isEmpty ? 1 : b.items.length),
      XlsxFormula("SUMIF('PACKING LIST'!\$A:\$A,A$r,'PACKING LIST'!\$F:\$F)", cached: b.quantity),
    ]);
  }
  final boxSheet = XlsxSheet(
    name: 'BOXES',
    headers: const ['C/No. 箱番号', '箱種', '長さ L', '幅 W', '高さ H', '容積 m³', '総重量 kg', '品目数', '総数量'],
    rows: boxRows,
    widths: const [10, 9, 9, 9, 9, 10, 11, 9, 10],
    lists: [
      if (nb > 0) ('B2:B${nb + 1}', 'BOX_TYPES!\$A\$2:\$A\$${(types.types.isEmpty ? 1 : types.types.length) + 1}'),
    ],
  );

  // BOX_TYPES.
  final typeSheet = XlsxSheet(
    name: 'BOX_TYPES',
    headers: const ['箱種', '長さ L (cm)', '幅 W (cm)', '高さ H (cm)', '箱の自重 kg', 'メモ'],
    rows: [
      for (final t in types.types) [t.name, t.dims.$1, t.dims.$2, t.dims.$3, t.tareKg == null ? null : _r3(t.tareKg!), t.memo],
    ],
    widths: const [9, 12, 12, 12, 12, 36],
  );

  // SUMMARY: by 品番, else JAN, else 品名.
  final seen = <String, ({String col, String value, String? maker, String? jan, String? code, int qty, int boxes})>{};
  for (final b in boxes) {
    final inBox = <String>{};
    for (final i in b.items) {
      final (col, value) = i.code != null ? ('D', i.code!) : (i.jan != null ? ('E', i.jan!) : ('B', i.name ?? ''));
      final k = '$col|$value';
      final s = seen[k];
      final counted = inBox.add(k);
      seen[k] = (
        col: col,
        value: value,
        maker: s?.maker ?? i.maker,
        jan: s?.jan ?? i.jan,
        code: s?.code ?? i.code,
        qty: (s?.qty ?? 0) + i.quantity,
        boxes: (s?.boxes ?? 0) + (counted ? 1 : 0),
      );
    }
  }
  final summary = XlsxSheet(
    name: 'SUMMARY',
    headers: const ['品番 / JAN / 品名', 'メーカー', 'JAN', '総数量', '行数'],
    rows: [
      for (final (i, s) in seen.values.indexed)
        [
          s.value,
          s.maker ?? '',
          s.jan ?? '',
          XlsxFormula("SUMIF('PACKING LIST'!\$${s.col}:\$${s.col},A${i + 2},'PACKING LIST'!\$F:\$F)", cached: s.qty),
          XlsxFormula("COUNTIF('PACKING LIST'!\$${s.col}:\$${s.col},A${i + 2})", cached: s.boxes),
        ],
    ],
    widths: const [20, 16, 15, 10, 8],
  );
  return buildXlsxBook([list, boxSheet, typeSheet, summary]);
}

String _esc(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s);

/// The packing list as a page to look at or print: the heading, a row for
/// each product in each box (box values on its first row) and the totals.
String packingListHtml(List<PackBox> boxes, {String title = 'PACKING LIST', PlHeader? header}) {
  final b = StringBuffer()
    ..write('<!doctype html><html><head><meta charset="utf-8"><title>${_esc(title)}</title><style>'
        'body{font-family:system-ui,sans-serif;margin:24px;color:#222}h1{font-size:20px;margin:0 0 12px}'
        'table{border-collapse:collapse;font-size:12px;width:100%}th,td{border:1px solid #bbb;padding:3px 6px;vertical-align:top}'
        'th{background:#e7eef7}td.n{text-align:right}tr.first td{border-top:2px solid #666}td.miss{background:#fff2a8}'
        '.head td{border:none;padding:1px 8px 1px 0}.tot td{font-weight:bold;border:none}'
        '@media print{body{margin:8mm}}</style></head><body>')
    ..write('<h1>${_esc(title)}</h1>');
  if (header != null) {
    b.write('<table class="head">');
    for (final (k, v) in header.lines) {
      if (v.isEmpty) continue;
      b.write('<tr><td><b>${_esc(k)}</b></td><td>${_esc(v)}</td></tr>');
    }
    b.write('</table><br>');
  }
  b.write('<table><tr><th>C/No.</th><th>Description</th><th>Maker</th><th>Item No.</th><th>JAN</th><th>Q\'ty</th>'
      '<th>Box type</th><th>Measurement (cm)</th><th>G.W. (kg)</th><th>CBM</th></tr>');
  final marked = boxes.map((x) => x.mark ?? '').toSet().length > 1;
  for (final x in boxes) {
    final items = x.items.isEmpty ? const [PackItem(quantity: 0)] : x.items;
    for (final (i, it) in items.indexed) {
      final lead = i == 0;
      b.write('<tr${lead ? ' class="first"' : ''}><td>${_esc(marked ? x.label : '${x.boxNo}')}</td>'
          '<td>${_esc(it.name ?? '')}</td><td>${_esc(it.maker ?? '')}</td><td>${_esc(it.code ?? '')}</td>'
          '<td${it.jan == null ? ' class="miss"' : ''}>${_esc(it.jan ?? '')}</td><td class="n">${it.quantity}</td>'
          '<td>${lead ? _esc(x.ownCase ? '元箱' : (x.cartonType ?? '')) : ''}</td>'
          '<td>${lead ? _esc(x.sizeText) : ''}</td>'
          '<td class="n">${lead && x.weightKg != null ? _n(_r3(x.weightKg!)) : ''}</td>'
          '<td class="n">${lead && x.volumeM3 != null ? _n(_r4(x.volumeM3!)) : ''}</td></tr>');
    }
  }
  final qty = boxes.fold(0, (a, x) => a + x.quantity);
  final kg = boxes.fold(0.0, (a, x) => a + (x.weightKg ?? 0));
  final cbm = boxes.fold(0.0, (a, x) => a + (x.volumeM3 ?? 0));
  b
    ..write('</table><br><table class="tot">')
    ..write('<tr><td>Total cartons 箱数</td><td>${boxes.length}</td></tr>')
    ..write("<tr><td>Total Q'ty 総数量</td><td>$qty</td></tr>")
    ..write('<tr><td>Total G.W. (kg) 総重量</td><td>${_n(_r3(kg))}</td></tr>')
    ..write('<tr><td>Total CBM 総容積</td><td>${_n(_r4(cbm))}</td></tr>')
    ..write('</table></body></html>');
  return b.toString();
}
