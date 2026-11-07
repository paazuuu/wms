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
        // What is left once the 出庫予定 already registered take theirs (0201).
        onHand: m.productId == null ? null : m.free,
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

/// The places it may be ordered from: their names are written over these.
const inboundSupplierSlots = ['（表示名１）', '（表示名２）', '（表示名３）'];

/// The columns of 入荷の提案, the same on the page and in the Excel: a plan to
/// order from, so no 状態 (whether a JAN is in the library does not matter
/// here); 入荷する数 split over three suppliers.
const inboundProposalHeaders = [
  '品番', 'JAN', '商品名', 'メーカー', '仕入先', '出荷明細の数量', '在庫', '不足（入荷が必要）', '入荷する数',
  ...inboundSupplierSlots,
  '前回の仕入れ値', '金額の目安', '注番', '出荷明細の行',
];

double _r2(double v) => (v * 100).roundToDouble() / 100;

/// 入荷の提案 to plan the orders with: one row a product — 不足, and 入荷する
/// 数 (as much as is short to begin with, to edit) split over up to three
/// suppliers: their names written over （表示名１）…（表示名３）, the numbers
/// for ２ and ３ typed in, and １ takes the rest (= 入荷する数 − ２ − ３), so
/// the three always add up to it. 金額の目安 = 入荷する数 × 前回の仕入れ値.
/// Totals under, each supplier's too. Only a plan: what comes in is taken in
/// from the suppliers' invoices later.
Uint8List buildInboundProposalXlsx(List<InboundNeed> needs, {String? title}) {
  final rows = <List<Object?>>[];
  final top = <List<Object?>>[
    ['入荷の提案（出荷明細の不足分）'],
    if (title != null) ['出荷明細', title],
    ['使い方', '（表示名１）〜（表示名３）を仕入先の会社名に書き換え、（表示名２）（表示名３）に数を入れてください。（表示名１）は残り（入荷する数 − ２ − ３）が式で入ります。'],
    [],
  ];
  final first = top.length + 2;
  for (final (i, n) in needs.indexed) {
    final r = first + i;
    rows.add([
      n.code,
      n.jan,
      n.name,
      n.maker,
      n.supplier,
      n.asked,
      n.onHand,
      n.need,
      n.need,
      XlsxFormula('I$r-K$r-L$r', cached: n.need),
      null,
      null,
      n.lastPrice,
      n.lastPrice == null ? null : XlsxFormula('I$r*M$r', cached: _r2(n.need * n.lastPrice!)),
      n.orderNumbers.join(', '),
      n.rows.join(', '),
    ]);
  }
  final last = first + needs.length - 1;
  final need = needs.fold<int>(0, (a, n) => a + n.need);
  final amount = needs.fold(0.0, (a, n) => a + (n.lastPrice == null ? 0 : n.need * n.lastPrice!));
  XlsxFormula sum(String c, num cached) => XlsxFormula('SUM($c$first:$c$last)', cached: cached);
  return buildXlsxBook([
    XlsxSheet(
      name: '入荷の提案',
      top: top,
      headers: inboundProposalHeaders,
      rows: rows,
      widths: const [16, 16, 30, 14, 14, 10, 8, 12, 10, 14, 14, 14, 10, 12, 12, 14],
      bottom: needs.isEmpty
          ? const []
          : [
              [
                '合計', null, null, null, null,
                sum('F', needs.fold<int>(0, (a, n) => a + n.asked)),
                null,
                sum('H', need),
                sum('I', need),
                sum('J', need),
                sum('K', 0),
                sum('L', 0),
                null,
                sum('N', _r2(amount)),
              ],
            ],
    ),
  ]);
}

String _esc(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s);

/// The same as a page to look at, plan on and print: the supplier names and
/// the numbers for ２ and ３ can be typed in; １ takes the rest and the totals
/// follow, as in the Excel.
String inboundProposalHtml(List<InboundNeed> needs, {String? title}) {
  final b = StringBuffer()
    ..write('<!doctype html><html><head><meta charset="utf-8"><title>入荷の提案</title><style>'
        'body{font-family:system-ui,sans-serif;margin:24px;color:#222}h1{font-size:20px;margin:0 0 4px}'
        '.hint{font-size:12px;color:#555;margin:4px 0}'
        'table{border-collapse:collapse;font-size:12px;width:100%;margin-top:12px}th,td{border:1px solid #bbb;padding:3px 6px}'
        'th{background:#e7eef7}td.n{text-align:right}td.s{background:#f4f8ff}tfoot td{font-weight:bold}'
        'input{font:inherit;border:1px solid #ccd;border-radius:3px;padding:1px 3px;box-sizing:border-box}'
        'input.q{width:64px;text-align:right}th input{width:96px;font-weight:bold;background:#fff}'
        '@media print{input{border:none;background:none}}'
        '</style></head><body><h1>入荷の提案（出荷明細の不足分）</h1>');
  if (title != null) b.write('<div>出荷明細: ${_esc(title)}</div>');
  b.write('<div class="hint">（表示名１）〜（表示名３）を仕入先の会社名に書き換え、（表示名２）（表示名３）に数を入れてください。'
      '（表示名１）は残り（入荷する数 − ２ − ３）になります。おおよその計画用です。</div>');
  b.write('<table><thead><tr>');
  for (final h in inboundProposalHeaders) {
    b.write(inboundSupplierSlots.contains(h)
        ? '<th><input value="${_esc(h)}" aria-label="${_esc(h)}"></th>'
        : '<th>${_esc(h)}</th>');
  }
  b.write('</tr></thead><tbody>');
  String n(num? v) => v == null ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
  for (final x in needs) {
    b.write('<tr>'
        '<td>${_esc(x.code ?? '')}</td><td>${_esc(x.jan ?? '')}</td><td>${_esc(x.name ?? '')}</td>'
        '<td>${_esc(x.maker ?? '')}</td><td>${_esc(x.supplier ?? '')}</td>'
        '<td class="n">${x.asked}</td><td class="n">${n(x.onHand)}</td><td class="n"><b>${x.need}</b></td>'
        '<td class="n"><input class="q t" type="number" min="0" value="${x.need}"></td>'
        '<td class="n s s1">${x.need}</td>'
        '<td class="n s"><input class="q s2" type="number" min="0"></td>'
        '<td class="n s"><input class="q s3" type="number" min="0"></td>'
        '<td class="n p" data-p="${x.lastPrice ?? ''}">${n(x.lastPrice)}</td>'
        '<td class="n a">${x.lastPrice == null ? '' : n(_r2(x.need * x.lastPrice!))}</td>'
        '<td>${_esc(x.orderNumbers.join(', '))}</td><td>${_esc(x.rows.join(', '))}</td></tr>');
  }
  final need = needs.fold<int>(0, (a, x) => a + x.need);
  final amount = needs.fold(0.0, (a, x) => a + (x.lastPrice == null ? 0 : x.need * x.lastPrice!));
  b.write('</tbody><tfoot><tr><td colspan="5">合計 ${needs.length}品目</td>'
      '<td class="n">${needs.fold<int>(0, (a, x) => a + x.asked)}</td><td></td>'
      '<td class="n">$need</td><td class="n" id="tt">$need</td><td class="n" id="t1">$need</td>'
      '<td class="n" id="t2">0</td><td class="n" id="t3">0</td><td></td>'
      '<td class="n" id="ta">${n(_r2(amount))}</td><td></td><td></td>'
      '</tr></tfoot></table>');
  // The rest to １, and the totals, as the numbers are typed.
  b.write('<script>(function(){'
      'function v(e){var x=parseFloat(e&&e.value);return isNaN(x)?0:x}'
      'function r2(x){return Math.round(x*100)/100}'
      'function calc(){var T=0,A=0,S=[0,0,0];'
      'document.querySelectorAll("tbody tr").forEach(function(tr){'
      'var t=v(tr.querySelector(".t")),b=v(tr.querySelector(".s2")),c=v(tr.querySelector(".s3")),a=t-b-c;'
      'var one=tr.querySelector(".s1");one.textContent=a;one.style.color=a<0?"#c00":"";'
      'var p=parseFloat(tr.querySelector(".p").dataset.p);tr.querySelector(".a").textContent=isNaN(p)?"":r2(t*p);'
      'T+=t;S[0]+=a;S[1]+=b;S[2]+=c;if(!isNaN(p))A+=t*p});'
      'document.getElementById("tt").textContent=T;'
      '["t1","t2","t3"].forEach(function(id,i){document.getElementById(id).textContent=S[i]});'
      'document.getElementById("ta").textContent=r2(A)}'
      'document.addEventListener("input",calc)})();</script></body></html>');
  return b.toString();
}
