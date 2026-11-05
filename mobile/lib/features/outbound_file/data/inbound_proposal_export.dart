import 'dart:convert';
import 'dart:typed_data';

import '../../../core/export/xlsx.dart';
import '../domain/outbound_plan.dart';

/// One product the shipping list needs more of than there is: what it is,
/// how many the list asks, what is in stock, what must come in (不足).
class InboundNeed {
  InboundNeed({
    required this.status,
    this.code,
    this.jan,
    this.name,
    this.maker,
    this.supplier,
    this.onHand,
    this.lastPrice,
  });

  /// 未登録のJAN / JANなし / 在庫不足 …, as shown.
  final String status;
  final String? code;
  final String? jan;
  final String? name;
  final String? maker;
  final String? supplier;

  /// In stock (null: not a product of ours).
  final int? onHand;

  /// What it was last bought for.
  final double? lastPrice;
  int asked = 0;
  int need = 0;
  final orderNumbers = <String>{};
  final rows = <int>[];
}

/// What must come in for the list to ship, product by product (rows of one
/// product added up), in the list's order.
List<InboundNeed> inboundNeeds(List<OutboundPlanLine> lines, String Function(OutboundStatus) statusLabel) {
  final by = <String, InboundNeed>{};
  for (final l in lines) {
    if (l.need <= 0) continue;
    final m = l.match;
    final r = l.row;
    final key = m.productId != null
        ? 'p${m.productId}'
        : (r.jan.isNotEmpty ? 'j${r.jan}' : 'c${(r.code ?? '').toUpperCase()}|${r.maker ?? ''}|${r.name ?? ''}');
    final n = by.putIfAbsent(
      key,
      () => InboundNeed(
        status: statusLabel(l.status == OutboundStatus.ok ? OutboundStatus.short : l.status),
        code: r.code ?? m.sku,
        jan: r.jan.isNotEmpty ? r.jan : m.jan,
        name: m.name ?? r.name,
        maker: r.maker ?? m.maker,
        supplier: r.supplier,
        onHand: m.productId == null ? null : m.onHand,
        lastPrice: m.lastPrice,
      ),
    );
    n.asked += r.quantity ?? 0;
    n.need += l.need;
    if (r.orderNumber != null) n.orderNumbers.add(r.orderNumber!);
    n.rows.add(r.rowNo);
  }
  return by.values.toList();
}

const inboundProposalHeaders = [
  '品番', 'JAN', '商品名', 'メーカー', '仕入先', '状態', '出荷明細の数量', '在庫', '不足（入荷が必要）', '入荷する数', '前回の仕入れ値',
  '金額の目安', '注番', '出荷明細の行',
];

double _r2(double v) => (v * 100).roundToDouble() / 100;

/// 入荷の提案: one row a product — 不足 and, to edit, 入荷する数 (as much as
/// is short to begin with); 金額の目安 = 入荷する数 × 前回の仕入れ値, a
/// formula; the totals under. Products not in the library (未登録のJAN,
/// JANなし) are filled yellow: they are to be registered first.
Uint8List buildInboundProposalXlsx(List<InboundNeed> needs, {String? title}) {
  final rows = <List<Object?>>[];
  final flagged = <(int, int)>{};
  final top = <List<Object?>>[
    ['入荷の提案（出荷明細の不足分）'],
    if (title != null) ['出荷明細', title],
    [],
  ];
  final first = top.length + 2;
  for (final (i, n) in needs.indexed) {
    final r = first + i;
    if (n.onHand == null) flagged.add((i, 5));
    rows.add([
      n.code,
      n.jan,
      n.name,
      n.maker,
      n.supplier,
      n.status,
      n.asked,
      n.onHand,
      n.need,
      n.need,
      n.lastPrice,
      n.lastPrice == null ? null : XlsxFormula('J$r*K$r', cached: _r2(n.need * n.lastPrice!)),
      n.orderNumbers.join(', '),
      n.rows.join(', '),
    ]);
  }
  final last = first + needs.length - 1;
  final amount = needs.fold(0.0, (a, n) => a + (n.lastPrice == null ? 0 : n.need * n.lastPrice!));
  return buildXlsxBook([
    XlsxSheet(
      name: '入荷の提案',
      top: top,
      headers: inboundProposalHeaders,
      rows: rows,
      flagged: flagged,
      widths: const [16, 16, 30, 14, 14, 12, 10, 8, 12, 10, 10, 12, 12, 14],
      bottom: needs.isEmpty
          ? const []
          : [
              [
                '合計', null, null, null, null, null,
                XlsxFormula('SUM(G$first:G$last)', cached: needs.fold<int>(0, (a, n) => a + n.asked)),
                null,
                XlsxFormula('SUM(I$first:I$last)', cached: needs.fold<int>(0, (a, n) => a + n.need)),
                XlsxFormula('SUM(J$first:J$last)', cached: needs.fold<int>(0, (a, n) => a + n.need)),
                null,
                XlsxFormula('SUM(L$first:L$last)', cached: _r2(amount)),
              ],
            ],
    ),
  ]);
}

String _esc(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s);

/// The same as a page to look at (and print).
String inboundProposalHtml(List<InboundNeed> needs, {String? title}) {
  final b = StringBuffer()
    ..write('<!doctype html><html><head><meta charset="utf-8"><title>入荷の提案</title><style>'
        'body{font-family:system-ui,sans-serif;margin:24px;color:#222}h1{font-size:20px;margin:0 0 4px}'
        'table{border-collapse:collapse;font-size:12px;width:100%;margin-top:12px}th,td{border:1px solid #bbb;padding:3px 6px}'
        'th{background:#e7eef7}td.n{text-align:right}tr.new td{background:#fff2a8}tfoot td{font-weight:bold}'
        '</style></head><body><h1>入荷の提案（出荷明細の不足分）</h1>');
  if (title != null) b.write('<div>${_esc(title)}</div>');
  b.write('<table><thead><tr>');
  for (final h in inboundProposalHeaders) {
    if (h == '入荷する数') continue;
    b.write('<th>${_esc(h)}</th>');
  }
  b.write('</tr></thead><tbody>');
  String n(num? v) => v == null ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
  for (final x in needs) {
    b.write('<tr${x.onHand == null ? ' class="new"' : ''}>'
        '<td>${_esc(x.code ?? '')}</td><td>${_esc(x.jan ?? '')}</td><td>${_esc(x.name ?? '')}</td>'
        '<td>${_esc(x.maker ?? '')}</td><td>${_esc(x.supplier ?? '')}</td><td>${_esc(x.status)}</td>'
        '<td class="n">${x.asked}</td><td class="n">${n(x.onHand)}</td><td class="n"><b>${x.need}</b></td>'
        '<td class="n">${n(x.lastPrice)}</td><td class="n">${x.lastPrice == null ? '' : n(_r2(x.need * x.lastPrice!))}</td>'
        '<td>${_esc(x.orderNumbers.join(', '))}</td><td>${_esc(x.rows.join(', '))}</td></tr>');
  }
  final amount = needs.fold(0.0, (a, x) => a + (x.lastPrice == null ? 0 : x.need * x.lastPrice!));
  b.write('</tbody><tfoot><tr><td colspan="6">合計 ${needs.length}品目</td>'
      '<td class="n">${needs.fold<int>(0, (a, x) => a + x.asked)}</td><td></td>'
      '<td class="n">${needs.fold<int>(0, (a, x) => a + x.need)}</td><td></td><td class="n">${n(_r2(amount))}</td><td></td><td></td>'
      '</tr></tfoot></table></body></html>');
  return b.toString();
}
