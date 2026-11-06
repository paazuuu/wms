import 'dart:typed_data';

import '../../../core/export/xlsx.dart';
import '../domain/outbound_currency.dart';
import '../domain/outbound_plan.dart';

double _r2(double v) => (v * 100).roundToDouble() / 100;

/// The shipping list as read and checked here, to download again: every row
/// with what was found for it — 対象 (or 除外), 状態, the library's
/// product, 在庫 / 出庫数 / 不足 — and the list's own columns cleaned up.
/// 合計 (when the list had none) and 総重量 are formulas; the totals under.
/// Rows not found in the library are filled yellow. 仕入先 stays out (it is
/// ours to know). For a 在庫外出荷 ([proxy]) the stock columns are left out.
Uint8List buildOutboundPlanXlsx(
  List<OutboundPlanLine> lines, {
  required String Function(OutboundPlanLine) statusLabel,
  Map<int, RowCurrency> currency = const {},
  bool proxy = false,
  String? title,
  String? sheet,
}) {
  final headers = [
    '行', '対象', '状態', '商品名（ライブラリー）', '商品名（明細）', 'JAN', '品番', 'メーカー', '数量',
    if (!proxy) ...['在庫', '在庫から出せる数', '不足（入荷が必要）'],
    '単価（税抜）', '単価（税込）', '合計', '通貨', '前回の仕入れ値', '重量（g/個）', '総重量（kg）', '注番', '到着日', '発注日',
  ];
  String col(String h) => columnLetters(headers.indexOf(h));
  final top = <List<Object?>>[
    [proxy ? '在庫外出荷（照合結果）' : '出荷明細（照合結果）'],
    if (title != null) ['ファイル', title],
    if (sheet != null) ['シート', sheet],
    [],
  ];
  final first = top.length + 2;
  final rows = <List<Object?>>[];
  final flagged = <(int, int)>{};
  final status = headers.indexOf('状態');
  for (final (i, l) in lines.indexed) {
    final n = first + i;
    final r = l.row;
    final out = l.action == OutboundAction.skip;
    if (!proxy && !l.found && !out) flagged.add((i, status));
    final w = l.match.unitWeightG;
    rows.add([
      r.rowNo,
      out ? '除外' : '○',
      statusLabel(l),
      l.match.name,
      r.name,
      l.match.jan ?? (r.jan.isNotEmpty ? r.jan : (r.janRaw.isEmpty ? null : r.janRaw)),
      r.code ?? l.match.sku,
      r.maker ?? l.match.maker,
      r.quantity,
      if (!proxy) ...[
        l.stockBefore,
        l.action == OutboundAction.ship ? l.shipped : null,
        l.need > 0 ? l.need : null,
      ],
      r.priceEx,
      r.priceTax,
      r.amount ??
          (r.priceTax == null || r.quantity == null
              ? null
              : XlsxFormula('${col('数量')}$n*${col('単価（税込）')}$n', cached: _r2(r.quantity! * r.priceTax!))),
      (currency[r.rowNo]?.currency ?? PriceCurrency.jpy).wire,
      l.match.lastPrice,
      w,
      w == null ? null : XlsxFormula('${col('数量')}$n*${col('重量（g/個）')}$n/1000', cached: (r.quantity ?? 0) * w / 1000),
      r.orderNumber,
      r.arrival,
      r.orderDate,
    ]);
  }
  final last = first + lines.length - 1;
  XlsxFormula sum(String h, num cached) => XlsxFormula('SUM(${col(h)}$first:${col(h)}$last)', cached: cached);
  final kept = lines.where((l) => l.action != OutboundAction.skip);
  final bottom = lines.isEmpty
      ? const <List<Object?>>[]
      : [
          [
            for (final h in headers)
              switch (h) {
                '行' => '合計',
                '数量' => sum(h, lines.fold<int>(0, (a, l) => a + (l.row.quantity ?? 0))),
                '在庫から出せる数' => sum(h, kept.fold<int>(0, (a, l) => a + (l.action == OutboundAction.ship ? l.shipped : 0))),
                '不足（入荷が必要）' => sum(h, lines.fold<int>(0, (a, l) => a + l.need)),
                '合計' => sum(h, _r2(lines.fold<double>(0, (a, l) => a + (l.row.total ?? 0)))),
                '総重量（kg）' => sum(h, lines.fold<double>(0, (a, l) => a + (l.weightG ?? 0) / 1000)),
                _ => null,
              },
          ],
        ];
  return buildXlsxBook([
    XlsxSheet(
      name: proxy ? '在庫外出荷' : '出荷明細',
      top: top,
      headers: headers,
      rows: rows,
      flagged: flagged,
      bottom: bottom,
      widths: [
        for (final h in headers)
          switch (h) {
            '行' || '対象' || '通貨' => 6.0,
            '商品名（ライブラリー）' || '商品名（明細）' => 28.0,
            'JAN' || '品番' => 16.0,
            '状態' || 'メーカー' || '注番' => 12.0,
            _ => 10.0,
          },
      ],
    ),
  ]);
}
