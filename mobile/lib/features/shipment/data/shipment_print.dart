import 'package:barcode/barcode.dart';
import 'package:printing/printing.dart';

import '../domain/carton.dart';
import '../domain/sender_profile.dart';
import '../domain/shipment.dart';

/// Builds print-ready HTML for a shipment and hands it to the system print /
/// "Save as PDF" dialog. HTML (rather than the pdf canvas) is used so Japanese
/// product names render with the device's own fonts — no bundled CJK font, no
/// runtime font download. JAN barcodes are embedded as inline SVG.
class ShipmentPrinter {
  const ShipmentPrinter();

  String _esc(Object? v) => (v ?? '')
      .toString()
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// An inline SVG barcode for a JAN: EAN-13 when it is a valid 13-digit code,
  /// otherwise Code128. Returns '' when nothing sensible can be drawn.
  String _barcodeSvg(String jan) {
    final digits = jan.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    for (final bc in [
      if (digits.length == 13) Barcode.ean13(),
      if (digits.length == 8) Barcode.ean8(),
      Barcode.code128(),
    ]) {
      try {
        return bc.toSvg(digits, width: 132, height: 34, drawText: false);
      } catch (_) {
        // Try the next symbology.
      }
    }
    return '';
  }

  String _shell(String title, String body) => '''
<!doctype html><html><head><meta charset="utf-8"><style>
  * { font-family: sans-serif; }
  body { margin: 16px; color: #111; }
  h1 { font-size: 18px; margin: 0 0 2px; }
  .meta { font-size: 12px; color: #444; margin-bottom: 12px; }
  .meta span { margin-right: 16px; white-space: nowrap; }
  table { width: 100%; border-collapse: collapse; font-size: 12px; }
  th, td { border: 1px solid #999; padding: 5px 6px; text-align: left; vertical-align: middle; }
  th { background: #eee; }
  td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; }
  .jan { font-family: monospace; white-space: nowrap; }
  .bc svg { height: 34px; width: 132px; }
  .bc { width: 140px; }
  tfoot td { font-weight: bold; background: #f6f6f6; }
  .carton { page-break-inside: avoid; margin-bottom: 22px; }
  .box { font-size: 15px; font-weight: bold; margin: 0 0 4px; }
  /* Delivery slip */
  .slip-head { display: flex; justify-content: space-between; align-items: flex-start;
    border-bottom: 2px solid #111; padding-bottom: 8px; margin-bottom: 12px; }
  .slip-title { font-size: 22px; font-weight: bold; letter-spacing: 6px; }
  .to { font-size: 15px; margin-bottom: 10px; }
  .to b { font-size: 17px; border-bottom: 1px solid #111; padding: 0 24px 2px 4px; }
  .kv { font-size: 12px; color: #333; }
  .kv div { margin-bottom: 2px; }
  .sender { font-size: 12px; color: #222; text-align: right; margin: 4px 0 12px; }
  .sender .co { font-size: 14px; font-weight: bold; }
  .sender.inline { margin: 0; }
</style><title>$title</title></head><body>$body</body></html>''';

  /// The sender (差出人) block: company name bold, then the chosen lines.
  String _senderBlock(List<SenderLine> sender, {bool inline = false}) {
    if (sender.isEmpty) return '';
    final rows = sender
        .map((l) => l.key == 'company'
            ? '<div class="co">${_esc(l.text)}</div>'
            : '<div>${_esc(l.text)}</div>')
        .join();
    return '<div class="sender${inline ? ' inline' : ''}">$rows</div>';
  }

  String _headerBlock(Shipment s, String heading,
      [List<SenderLine> sender = const []]) {
    final m = <String>[];
    void add(String label, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        m.add('<span>$label: ${_esc(value)}</span>');
      }
    }

    add('出庫番号', s.shipmentNumber);
    add('整理番号', s.referenceNo);
    add('得意先', s.customerName);
    add('お客様コード', s.customerCode);
    add('日付', s.shipDate);
    return '<h1>${_esc(heading)}</h1>${_senderBlock(sender)}'
        '<div class="meta">${m.join()}</div>';
  }

  /// A plain (text) item table — used for the overall list.
  String _rows(Iterable<List<String>> rows, int total) {
    final body = rows
        .map((r) =>
            '<tr><td class="jan">${_esc(r[0])}</td><td>${_esc(r[1])}</td>'
            '<td>${_esc(r[2])}</td><td class="num">${_esc(r[3])}</td></tr>')
        .join();
    return '''
<table>
  <thead><tr><th>JAN</th><th>品名</th><th>規格</th><th class="num">数量</th></tr></thead>
  <tbody>$body</tbody>
  <tfoot><tr><td colspan="3">合計</td><td class="num">$total</td></tr></tfoot>
</table>''';
  }

  /// An item table with a JAN barcode column — used for carton contents.
  String _rowsWithBarcode(
      Iterable<List<String>> rows, int total) {
    final body = rows.map((r) {
      final svg = _barcodeSvg(r[0]);
      return '<tr><td class="bc">$svg</td><td class="jan">${_esc(r[0])}</td>'
          '<td>${_esc(r[1])}</td><td>${_esc(r[2])}</td>'
          '<td class="num">${_esc(r[3])}</td></tr>';
    }).join();
    return '''
<table>
  <thead><tr><th class="bc">バーコード</th><th>JAN</th><th>品名</th><th>規格</th><th class="num">数量</th></tr></thead>
  <tbody>$body</tbody>
  <tfoot><tr><td colspan="4">合計</td><td class="num">$total</td></tr></tfoot>
</table>''';
  }

  /// The whole shipment as one list.
  String overallHtml(Shipment s, {List<SenderLine> sender = const []}) {
    final rows = s.lines.map((l) =>
        [l.janCode, l.productName, l.spec ?? '', '${l.quantity}']);
    final body = _headerBlock(s, '出庫リスト', sender) + _rows(rows, s.totalUnits);
    return _shell('出庫リスト ${s.shipmentNumber}', body);
  }

  String _cartonSection(Shipment s, Carton c) {
    final boxes = s.cartonCount;
    final title = c.label == null || c.label!.isEmpty
        ? '段ボール #${c.cartonNo} / $boxes'
        : '段ボール #${c.cartonNo} / $boxes — ${c.label}';
    final rows = c.items.map((it) =>
        [it.janCode, it.productName, it.spec ?? '', '${it.quantity}']);
    return '<div class="carton"><div class="box">${_esc(title)}</div>'
        '${_rowsWithBarcode(rows, c.totalUnits)}</div>';
  }

  /// One carton's contents, with JAN barcodes.
  String cartonHtml(Shipment s, Carton c, {List<SenderLine> sender = const []}) {
    final body = _headerBlock(s, '内容リスト', sender) + _cartonSection(s, c);
    return _shell('段ボール${c.cartonNo} ${s.shipmentNumber}', body);
  }

  /// Every carton, one section per box (page-break between them), with barcodes.
  String allCartonsHtml(Shipment s, {List<SenderLine> sender = const []}) {
    final body = _headerBlock(s, '段ボール別 内容リスト', sender) +
        s.cartons.map((c) => _cartonSection(s, c)).join();
    return _shell('段ボール一覧 ${s.shipmentNumber}', body);
  }

  /// A formal delivery slip (送り状 / 納品書) for the whole shipment: recipient
  /// block, document metadata, the itemized list with unit price / amount when
  /// present, and totals.
  String deliverySlipHtml(Shipment s, {List<SenderLine> sender = const []}) {
    final hasMoney = s.lines.any((l) => l.unitPrice != null || l.amount != null);
    String money(int? v) => v == null ? '' : '¥${_esc(v)}';
    var amountTotal = 0;
    for (final l in s.lines) {
      amountTotal += l.amount ?? ((l.unitPrice ?? 0) * l.quantity);
    }

    final headCols = hasMoney
        ? '<th>JAN</th><th>品名</th><th>規格</th><th class="num">数量</th><th class="num">単価</th><th class="num">金額</th>'
        : '<th>JAN</th><th>品名</th><th>規格</th><th class="num">数量</th>';
    final rows = s.lines.map((l) {
      final base = '<td class="jan">${_esc(l.janCode)}</td>'
          '<td>${_esc(l.productName)}</td><td>${_esc(l.spec ?? '')}</td>'
          '<td class="num">${l.quantity}</td>';
      final extra = hasMoney
          ? '<td class="num">${money(l.unitPrice)}</td>'
              '<td class="num">${money(l.amount ?? (l.unitPrice != null ? l.unitPrice! * l.quantity : null))}</td>'
          : '';
      return '<tr>$base$extra</tr>';
    }).join();
    final footer = hasMoney
        ? '<tr><td colspan="3">合計</td><td class="num">${s.totalUnits}</td>'
            '<td></td><td class="num">¥$amountTotal</td></tr>'
        : '<tr><td colspan="3">合計</td><td class="num">${s.totalUnits}</td></tr>';

    final kv = <String>[];
    void add(String label, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        kv.add('<div>$label：${_esc(value)}</div>');
      }
    }

    add('発行日', s.shipDate);
    add('出庫番号', s.shipmentNumber);
    add('整理番号', s.referenceNo);
    add('お客様コード', s.customerCode);
    add('箱数', s.cartonCount > 0 ? '${s.cartonCount}' : null);

    final body = '''
<div class="slip-head">
  <div>
    <div class="to"><b>${_esc(s.customerName ?? '')}</b> 御中</div>
    <div class="kv">下記の通り納品いたします。</div>
  </div>
  <div>
    <div class="slip-title">送&nbsp;り&nbsp;状</div>
    <div class="kv">${kv.join()}</div>
    ${_senderBlock(sender, inline: true)}
  </div>
</div>
<table>
  <thead><tr>$headCols</tr></thead>
  <tbody>$rows</tbody>
  <tfoot>$footer</tfoot>
</table>''';
    return _shell('送り状 ${s.shipmentNumber}', body);
  }

  Future<void> _printHtml(String html) => Printing.layoutPdf(
      onLayout: (format) =>
          // ignore: deprecated_member_use
          Printing.convertHtml(format: format, html: html));

  Future<void> printOverall(Shipment s, {List<SenderLine> sender = const []}) =>
      _printHtml(overallHtml(s, sender: sender));
  Future<void> printCarton(Shipment s, Carton c,
          {List<SenderLine> sender = const []}) =>
      _printHtml(cartonHtml(s, c, sender: sender));
  Future<void> printAllCartons(Shipment s,
          {List<SenderLine> sender = const []}) =>
      _printHtml(allCartonsHtml(s, sender: sender));
  Future<void> printDeliverySlip(Shipment s,
          {List<SenderLine> sender = const []}) =>
      _printHtml(deliverySlipHtml(s, sender: sender));
}
