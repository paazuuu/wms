import 'package:printing/printing.dart';

import '../domain/carton.dart';
import '../domain/shipment.dart';

/// Builds print-ready HTML for a shipment and hands it to the system print /
/// "Save as PDF" dialog. HTML (rather than the pdf canvas) is used so Japanese
/// product names render with the device's own fonts — no bundled CJK font, no
/// runtime font download.
class ShipmentPrinter {
  const ShipmentPrinter();

  String _esc(Object? v) => (v ?? '')
      .toString()
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _shell(String title, String body) => '''
<!doctype html><html><head><meta charset="utf-8"><style>
  * { font-family: sans-serif; }
  body { margin: 16px; color: #111; }
  h1 { font-size: 18px; margin: 0 0 2px; }
  .meta { font-size: 12px; color: #444; margin-bottom: 12px; }
  .meta span { margin-right: 16px; white-space: nowrap; }
  table { width: 100%; border-collapse: collapse; font-size: 12px; }
  th, td { border: 1px solid #999; padding: 5px 6px; text-align: left; vertical-align: top; }
  th { background: #eee; }
  td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; }
  .jan { font-family: monospace; white-space: nowrap; }
  tfoot td { font-weight: bold; background: #f6f6f6; }
  .carton { page-break-inside: avoid; margin-bottom: 22px; }
  .box { font-size: 15px; font-weight: bold; margin: 0 0 4px; }
</style><title>$title</title></head><body>$body</body></html>''';

  String _headerBlock(Shipment s, String heading) {
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
    return '<h1>${_esc(heading)}</h1><div class="meta">${m.join()}</div>';
  }

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

  /// The whole shipment as one list.
  String overallHtml(Shipment s) {
    final rows = s.lines.map((l) =>
        [l.janCode, l.productName, l.spec ?? '', '${l.quantity}']);
    final body = _headerBlock(s, '出庫リスト') + _rows(rows, s.totalUnits);
    return _shell('出庫リスト ${s.shipmentNumber}', body);
  }

  String _cartonSection(Shipment s, Carton c) {
    final title = c.label == null || c.label!.isEmpty
        ? '段ボール #${c.cartonNo}'
        : '段ボール #${c.cartonNo} — ${c.label}';
    final rows = c.items.map((it) =>
        [it.janCode, it.productName, it.spec ?? '', '${it.quantity}']);
    return '<div class="carton"><div class="box">${_esc(title)}</div>'
        '${_rows(rows, c.totalUnits)}</div>';
  }

  /// One carton's contents.
  String cartonHtml(Shipment s, Carton c) {
    final body = _headerBlock(s, '内容リスト') + _cartonSection(s, c);
    return _shell('段ボール${c.cartonNo} ${s.shipmentNumber}', body);
  }

  /// Every carton, one section per box (page-break between them).
  String allCartonsHtml(Shipment s) {
    final body = _headerBlock(s, '段ボール別 内容リスト') +
        s.cartons.map((c) => _cartonSection(s, c)).join();
    return _shell('段ボール一覧 ${s.shipmentNumber}', body);
  }

  // convertHtml renders CJK with the device's own fonts, avoiding a bundled or
  // downloaded PDF font — the reason we build the documents as HTML.
  Future<void> _printHtml(String html) => Printing.layoutPdf(
      onLayout: (format) =>
          // ignore: deprecated_member_use
          Printing.convertHtml(format: format, html: html));

  Future<void> printOverall(Shipment s) => _printHtml(overallHtml(s));
  Future<void> printCarton(Shipment s, Carton c) => _printHtml(cartonHtml(s, c));
  Future<void> printAllCartons(Shipment s) => _printHtml(allCartonsHtml(s));
}
