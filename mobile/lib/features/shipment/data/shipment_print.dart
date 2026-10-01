import 'package:barcode/barcode.dart';
import 'package:printing/printing.dart';

import '../domain/carton.dart';
import '../domain/label_template.dart';
import '../domain/sender_profile.dart';
import '../../transfers/domain/transfer_order.dart';
import '../domain/shipment.dart';

/// One line of a downstream slip. Always our own notation: the server has
/// already turned whatever a trading company wrote into our JAN, maker, name
/// and 品番 (0105), so every document we send out reads the same.
class SlipLine {
  const SlipLine({
    required this.janCode,
    required this.productName,
    required this.quantity,
    this.maker,
    this.productCode,
    this.spec,
    this.unitPrice,
    this.amount,
  });

  final String janCode;
  final String productName;
  final String? maker;
  final String? productCode;
  final String? spec;
  final int quantity;
  final int? unitPrice;
  final int? amount;
}

/// One printed item row, in the fixed column order.
class _Item {
  const _Item(this.jan, this.maker, this.name, this.code, this.spec, this.quantity);
  final String jan;
  final String? maker;
  final String name;
  final String? code;
  final String? spec;
  final int quantity;
}

/// Everything a 送り状 prints, whichever document the goods left on.
class SlipDocument {
  const SlipDocument({
    required this.recipient,
    required this.number,
    required this.lines,
    this.recipientAddress,
    this.recipientPhone,
    this.referenceNo,
    this.customerCode,
    this.date,
    this.origin,
    this.destinationCountry,
    this.cartonCount = 0,
  });

  final String recipient;
  final String? recipientAddress;
  final String? recipientPhone;
  final String number;
  final String? referenceNo;
  final String? customerCode;
  final String? date;

  /// The warehouse the goods left from, when that is not obvious (transfers).
  final String? origin;

  /// Printed when the goods cross a border.
  final String? destinationCountry;
  final int cartonCount;
  final List<SlipLine> lines;

  factory SlipDocument.fromShipment(Shipment s) => SlipDocument(
        recipient: s.customerName ?? '',
        number: s.shipmentNumber,
        referenceNo: s.referenceNo,
        customerCode: s.customerCode,
        date: s.shipDate,
        cartonCount: s.cartonCount,
        lines: [
          for (final l in s.lines)
            SlipLine(
              janCode: l.janCode,
              productName: l.productName,
              maker: l.maker,
              productCode: l.productCode,
              spec: l.spec,
              quantity: l.quantity,
              unitPrice: l.unitPrice,
              amount: l.amount,
            ),
        ],
      );

  /// What left counts once picking is done; before that, what was asked for.
  factory SlipDocument.fromTransfer(TransferOrder t) => SlipDocument(
        recipient: t.destinationWarehouseName ?? '#${t.destinationWarehouseId}',
        recipientAddress: t.destinationAddress,
        recipientPhone: t.destinationPhone,
        number: t.transferNumber ?? '#${t.id}',
        date: _date(t.shippedAt ?? t.createdAt),
        origin: t.sourceWarehouseName ?? '#${t.sourceWarehouseId}',
        destinationCountry: t.crossBorder ? t.destinationCountryCode : null,
        lines: [
          for (final l in t.lines)
            if ((l.pickedQuantity ?? l.requestedQuantity) > 0)
              SlipLine(
                janCode: l.janCode,
                productName: l.productName,
                quantity: l.pickedQuantity ?? l.requestedQuantity,
              ),
        ],
      );

  static String? _date(DateTime? d) => d == null
      ? null
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

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

  /// A Japanese heading with its English beneath, as every printed document
  /// carries both: the goods often go to people who read only one.
  static String bi(String ja, String en) => '$ja<span class="en">$en</span>';

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
  .en { display: block; font-size: 9px; font-weight: normal; color: #666; letter-spacing: 0; }
  .meta .en, .kv .en { display: inline; margin-left: 3px; }
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

    add(bi('出庫番号', 'Shipment No.'), s.shipmentNumber);
    add(bi('整理番号', 'Ref. No.'), s.referenceNo);
    add(bi('得意先', 'Customer'), s.customerName);
    add(bi('お客様コード', 'Customer code'), s.customerCode);
    add(bi('日付', 'Date'), s.shipDate);
    return '<h1>${_esc(heading)}</h1>${_senderBlock(sender)}'
        '<div class="meta">${m.join()}</div>';
  }

  /// The item columns every outbound document prints, in this order, whatever
  /// headings the trading company used on its own paperwork.
  static const itemHeadings = ['JANコード', 'メーカー', '品名', '品番', '規格'];
  static const itemHeadingsEn = ['JAN', 'Maker', 'Product', 'Item code', 'Spec'];

  String get _itemHead => [
        for (var i = 0; i < itemHeadings.length; i++)
          '<th>${bi(itemHeadings[i], itemHeadingsEn[i])}</th>'
      ].join();

  static final _qtyHead = '<th class="num">${bi('数量', 'Qty')}</th>';
  static final _totalCell = bi('合計', 'Total');

  String _itemCells(_Item r) => '<td class="jan">${_esc(r.jan)}</td>'
      '<td>${_esc(r.maker)}</td><td>${_esc(r.name)}</td>'
      '<td>${_esc(r.code)}</td><td>${_esc(r.spec)}</td>';

  /// A plain (text) item table — used for the overall list.
  String _rows(Iterable<_Item> rows, int total) {
    final body = rows
        .map((r) => '<tr>${_itemCells(r)}<td class="num">${r.quantity}</td></tr>')
        .join();
    return '''
<table>
  <thead><tr>$_itemHead$_qtyHead</tr></thead>
  <tbody>$body</tbody>
  <tfoot><tr><td colspan="${itemHeadings.length}">$_totalCell</td><td class="num">$total</td></tr></tfoot>
</table>''';
  }

  /// An item table with a JAN barcode column — used for carton contents.
  String _rowsWithBarcode(Iterable<_Item> rows, int total) {
    final body = rows.map((r) {
      final svg = _barcodeSvg(r.jan);
      return '<tr><td class="bc">$svg</td>${_itemCells(r)}'
          '<td class="num">${r.quantity}</td></tr>';
    }).join();
    return '''
<table>
  <thead><tr><th class="bc">${bi('バーコード', 'Barcode')}</th>$_itemHead$_qtyHead</tr></thead>
  <tbody>$body</tbody>
  <tfoot><tr><td colspan="${itemHeadings.length + 1}">$_totalCell</td><td class="num">$total</td></tr></tfoot>
</table>''';
  }

  /// The whole shipment as one list.
  String overallHtml(Shipment s, {List<SenderLine> sender = const []}) {
    final rows = s.lines.map((l) => _Item(
        l.janCode, l.maker, l.productName, l.productCode, l.spec, l.quantity));
    final body = _headerBlock(s, '出庫リスト / Shipping List', sender) + _rows(rows, s.totalUnits);
    return _shell('出庫リスト ${s.shipmentNumber}', body);
  }

  String _cartonSection(Shipment s, Carton c) {
    final boxes = s.cartonCount;
    final title = c.label == null || c.label!.isEmpty
        ? '段ボール #${c.cartonNo} / $boxes (Carton)'
        : '段ボール #${c.cartonNo} / $boxes (Carton) — ${c.label}';
    // A carton item carries only the JAN and name; the maker and 品番 come
    // from the shipment line it was packed from.
    final byJan = {for (final l in s.lines) l.janCode: l};
    final rows = c.items.map((it) {
      final line = byJan[it.janCode];
      return _Item(it.janCode, line?.maker, it.productName, line?.productCode,
          it.spec ?? line?.spec, it.quantity);
    });
    return '<div class="carton"><div class="box">${_esc(title)}</div>'
        '${_rowsWithBarcode(rows, c.totalUnits)}</div>';
  }

  /// One carton's contents, with JAN barcodes.
  String cartonHtml(Shipment s, Carton c, {List<SenderLine> sender = const []}) {
    final body = _headerBlock(s, '内容リスト / Packing List', sender) + _cartonSection(s, c);
    return _shell('段ボール${c.cartonNo} ${s.shipmentNumber}', body);
  }

  /// Every carton, one section per box (page-break between them), with barcodes.
  String allCartonsHtml(Shipment s, {List<SenderLine> sender = const []}) {
    final body = _headerBlock(s, '段ボール別 内容リスト / Packing List by Carton', sender) +
        s.cartons.map((c) => _cartonSection(s, c)).join();
    return _shell('段ボール一覧 ${s.shipmentNumber}', body);
  }

  /// A formal delivery slip (送り状 / 納品書) for the whole shipment: recipient
  /// block, document metadata, the itemized list with unit price / amount when
  /// present, and totals.
  String deliverySlipHtml(Shipment s, {List<SenderLine> sender = const []}) =>
      slipHtml(SlipDocument.fromShipment(s), sender: sender);

  /// The same 送り状 for a transfer to another warehouse, so every document that
  /// goes out with goods reads the same whatever made it (0087).
  String transferSlipHtml(TransferOrder t, {List<SenderLine> sender = const []}) =>
      slipHtml(SlipDocument.fromTransfer(t), sender: sender);

  /// The one downstream slip layout. Everything that sends goods out fills a
  /// [SlipDocument] and prints through here.
  String slipHtml(SlipDocument d, {List<SenderLine> sender = const []}) {
    final hasMoney = d.lines.any((l) => l.unitPrice != null || l.amount != null);
    String money(int? v) => v == null ? '' : '¥${_esc(v)}';
    var amountTotal = 0;
    var units = 0;
    for (final l in d.lines) {
      amountTotal += l.amount ?? ((l.unitPrice ?? 0) * l.quantity);
      units += l.quantity;
    }

    final headCols = hasMoney
        ? '$_itemHead$_qtyHead<th class="num">${bi('単価', 'Unit price')}</th><th class="num">${bi('金額', 'Amount')}</th>'
        : '$_itemHead$_qtyHead';
    final rows = d.lines.map((l) {
      final cells = _itemCells(_Item(
          l.janCode, l.maker, l.productName, l.productCode, l.spec, l.quantity));
      final base = '$cells<td class="num">${l.quantity}</td>';
      final extra = hasMoney
          ? '<td class="num">${money(l.unitPrice)}</td>'
              '<td class="num">${money(l.amount ?? (l.unitPrice != null ? l.unitPrice! * l.quantity : null))}</td>'
          : '';
      return '<tr>$base$extra</tr>';
    }).join();
    final footer = hasMoney
        ? '<tr><td colspan="${itemHeadings.length}">$_totalCell</td><td class="num">$units</td>'
            '<td></td><td class="num">¥$amountTotal</td></tr>'
        : '<tr><td colspan="${itemHeadings.length}">$_totalCell</td><td class="num">$units</td></tr>';

    final kv = <String>[];
    void add(String label, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        kv.add('<div>$label：${_esc(value)}</div>');
      }
    }

    add(bi('発行日', 'Issued'), d.date);
    add(bi('出庫番号', 'Shipment No.'), d.number);
    add(bi('整理番号', 'Ref. No.'), d.referenceNo);
    add(bi('お客様コード', 'Customer code'), d.customerCode);
    add(bi('出荷元', 'Ship from'), d.origin);
    add(bi('仕向国', 'Destination'), d.destinationCountry);
    add(bi('箱数', 'Cartons'), d.cartonCount > 0 ? '${d.cartonCount}' : null);

    final address = [d.recipientAddress, d.recipientPhone]
        .where((v) => v != null && v.trim().isNotEmpty)
        .map((v) => '<div class="kv">${_esc(v)}</div>')
        .join();

    final body = '''
<div class="slip-head">
  <div>
    <div class="to"><b>${_esc(d.recipient)}</b> 御中</div>
    $address
    <div class="kv">下記の通り納品いたします。<span class="en">Please find the goods listed below.</span></div>
  </div>
  <div>
    <div class="slip-title">送&nbsp;り&nbsp;状<span class="en">DELIVERY NOTE</span></div>
    <div class="kv">${kv.join()}</div>
    ${_senderBlock(sender, inline: true)}
  </div>
</div>
<table>
  <thead><tr>$headCols</tr></thead>
  <tbody>$rows</tbody>
  <tfoot>$footer</tfoot>
</table>''';
    return _shell('送り状 ${d.number}', body);
  }

  /// The variable set §20 defines, filled in for one carton of one shipment.
  ///
  /// `product_name`/`jan`/`lot` describe the carton's contents: a single-SKU box
  /// names the item, a mixed box says how many kinds are inside rather than
  /// picking one arbitrarily and printing a label that lies about the rest.
  Map<String, String?> cartonLabelValues(
    Shipment s,
    Carton c, {
    List<SenderLine> sender = const [],
    String? warehouseName,
  }) {
    final janCodes = {for (final it in c.items) it.janCode}.toList();
    final single = janCodes.length == 1 ? c.items.first : null;
    // Same "single vs. ambiguous" rule as product_name/jan: a box is only
    // printed with one lot when every parcel in it agrees on that lot — a box
    // split across two lots of the same JAN gets no lot row rather than one
    // that names only the first parcel and silently mislabels the rest.
    final lotCodes = {
      for (final it in c.items)
        if (it.lotCode != null) it.lotCode!,
    };
    final company = sender
        .where((l) => l.key == 'company')
        .map((l) => l.text)
        .firstOrNull;
    return {
      'company': company,
      'customer': s.customerName,
      'shipment_no': s.shipmentNumber,
      'carton_no': '${c.cartonNo}',
      'carton_total': '${s.cartonCount}',
      'product_name': single?.productName ??
          (janCodes.isEmpty ? null : '${janCodes.length} 品目'),
      'jan': single?.janCode,
      'sku': single?.spec,
      'lot': lotCodes.length == 1 ? lotCodes.first : null,
      'quantity': '${c.totalUnits}',
      'warehouse': warehouseName,
    };
  }

  /// One carton label per §17/§19: the template's text rows, a JAN barcode when
  /// the box holds a single SKU, and the carton's own QR so the box can be
  /// identified by scan at the dock.
  String cartonLabelHtml(
    Shipment s,
    Carton c, {
    LabelTemplate template = LabelTemplates.carton,
    List<SenderLine> sender = const [],
    String? warehouseName,
  }) {
    final values =
        cartonLabelValues(s, c, sender: sender, warehouseName: warehouseName);
    final rows = template.render(values);
    final code = template.renderCode(values);
    final qr = template.renderQr(values);

    final body = '''
<div class="label">
  <div class="label-text">
    ${rows.map((r) => '<div class="lr">${_esc(r)}</div>').join()}
  </div>
  <div class="label-codes">
    ${qr == null ? '' : '<div class="qr">${_qrSvg(qr)}</div>'}
    ${code == null ? '' : '<div class="bc1">${_barcodeSvg(code)}<div class="jan">${_esc(code)}</div></div>'}
  </div>
</div>''';
    return _labelShell('ラベル ${s.shipmentNumber} #${c.cartonNo}', body);
  }

  /// Every carton's label, one per page.
  String allCartonLabelsHtml(
    Shipment s, {
    LabelTemplate template = LabelTemplates.carton,
    List<SenderLine> sender = const [],
    String? warehouseName,
  }) {
    final body = s.cartons
        .map((c) => cartonLabelHtml(s, c,
            template: template, sender: sender, warehouseName: warehouseName))
        .map(_labelBodyOf)
        .join();
    return _labelShell('箱ラベル ${s.shipmentNumber}', body);
  }

  /// A QR as inline SVG. Empty string when the payload cannot be encoded.
  String _qrSvg(String payload) {
    try {
      return Barcode.qrCode()
          .toSvg(payload, width: 110, height: 110, drawText: false);
    } catch (_) {
      return '';
    }
  }

  /// Labels get their own page shell: big type, one label per page, and no
  /// document chrome — it is going on a box, not into a folder.
  String _labelShell(String title, String body) => '''
<!doctype html><html><head><meta charset="utf-8"><style>
  * { font-family: sans-serif; }
  body { margin: 0; color: #000; }
  .label { page-break-after: always; box-sizing: border-box; width: 100%;
    padding: 14px 16px; display: flex; justify-content: space-between;
    align-items: flex-start; gap: 12px; border-bottom: 1px dashed #bbb; }
  .label:last-child { page-break-after: auto; }
  .label-text { flex: 1; min-width: 0; }
  .lr { font-size: 16px; line-height: 1.45; word-break: break-word; }
  .lr:first-child { font-size: 13px; color: #333; }
  .lr:nth-child(4) { font-size: 26px; font-weight: bold; letter-spacing: 1px; }
  .label-codes { text-align: center; }
  .qr svg { width: 110px; height: 110px; }
  .bc1 { margin-top: 8px; }
  .bc1 svg { width: 132px; height: 34px; }
  .jan { font-family: monospace; font-size: 11px; }
</style><title>$title</title></head><body>$body</body></html>''';

  /// Pulls the `<div class="label">…</div>` out of a rendered single label so
  /// several can share one page shell.
  String _labelBodyOf(String html) {
    final start = html.indexOf('<body>');
    final end = html.lastIndexOf('</body>');
    if (start < 0 || end < 0) return html;
    return html.substring(start + '<body>'.length, end);
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
  Future<void> printTransferSlip(TransferOrder t,
          {List<SenderLine> sender = const []}) =>
      _printHtml(transferSlipHtml(t, sender: sender));

  Future<void> printDeliverySlip(Shipment s,
          {List<SenderLine> sender = const []}) =>
      _printHtml(deliverySlipHtml(s, sender: sender));

  /// §19's flow ends at a print job, and the system print dialog is the preview
  /// step the spec makes mandatory (印刷前プレビューを必須にする) — it shows the
  /// rendered pages before anything reaches a printer.
  Future<void> printCartonLabel(Shipment s, Carton c,
          {LabelTemplate template = LabelTemplates.carton,
          List<SenderLine> sender = const [],
          String? warehouseName}) =>
      _printHtml(cartonLabelHtml(s, c,
          template: template, sender: sender, warehouseName: warehouseName));

  Future<void> printAllCartonLabels(Shipment s,
          {LabelTemplate template = LabelTemplates.carton,
          List<SenderLine> sender = const [],
          String? warehouseName}) =>
      _printHtml(allCartonLabelsHtml(s,
          template: template, sender: sender, warehouseName: warehouseName));
}
