import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../core/export/xlsx.dart';
import '../../shipment/domain/sender_profile.dart';
import '../domain/outbound.dart';
import '../domain/pricing.dart';

/// The shipment sheet sent to the other company (0139): who it goes to, who
/// sends it, and what goes — in Japanese with English beside each heading,
/// so it reads abroad too. [number] is empty for a draft not saved yet.
Uint8List buildShipmentSheetXlsx({
  required String number,
  required ShipDestination? to,
  required List<OutboundSheetLine> lines,
  SenderProfile? sender,
  String? shipDate,
  String? note,
  String? warehouseName,
  String? carrier,
  String? trackingNumber,
  List<PriceColumn> priceColumns = const [],
  DateTime? now,
}) {
  final top = <List<Object?>>[
    ['出荷明細書 / Packing List'],
    ['出庫番号 / No.', number.isEmpty ? '（下書き / Draft）' : number],
    ['作成日 / Date', DateFormat('y/MM/dd').format(now ?? DateTime.now())],
    if (shipDate != null) ['出荷日 / Ship date', shipDate],
    [],
    ['出荷先 / Ship to', to?.name ?? ''],
    if (to?.department != null) ['', to!.department],
    if (to?.contactName != null) ['ご担当 / Attn.', '${to!.contactName} 様'],
    if (to != null && to.addressLine.isNotEmpty) ['住所 / Address', to.addressLine],
    if (to?.countryCode != null) ['国 / Country', to!.countryCode],
    if (to?.phone != null) ['電話 / Tel', to!.phone],
    if (to?.email != null) ['メール / Email', to!.email],
    if (sender != null && sender.companyName.isNotEmpty) ...[
      [],
      ['差出人 / From', sender.companyName],
      if (sender.postalCode.isNotEmpty || sender.address.isNotEmpty)
        ['住所 / Address', [if (sender.postalCode.isNotEmpty) '〒${sender.postalCode}', sender.address].join(' ').trim()],
      if (sender.phone.isNotEmpty) ['電話 / Tel', sender.phone],
      if (sender.contact.isNotEmpty) ['担当 / Contact', sender.contact],
    ],
    if (warehouseName != null) ['出荷元倉庫 / Warehouse', warehouseName],
    if (carrier != null) ['運送会社 / Carrier', carrier],
    if (trackingNumber != null) ['送り状番号 / Tracking', trackingNumber],
    if (note != null) ['備考 / Note', note],
    [],
  ];
  final total = lines.fold<int>(0, (s, l) => s + l.quantity);
  // The prices chosen, in a fixed order; the amount is at 出荷単価 when it is
  // shown, else at the first price shown.
  final cols = [for (final c in PriceColumn.values) if (priceColumns.contains(c)) c];
  final amountBy = cols.contains(PriceColumn.ship) ? PriceColumn.ship : cols.firstOrNull;
  double? amount(OutboundSheetLine l) {
    final p = amountBy == null ? null : l.price(amountBy);
    return p == null ? null : (p * l.quantity * 100).roundToDouble() / 100;
  }

  final sum = amountBy == null ? null : lines.fold<double>(0, (s, l) => s + (amount(l) ?? 0));
  return buildXlsx(
    sheetName: number.isEmpty ? '出荷明細' : number,
    top: top,
    headers: [
      'No.', 'JANコード / JAN', '品名 / Product', '英語名 / English name', 'メーカー / Maker', '品番 / Item code',
      '数量 / Qty', '単位 / Unit',
      for (final c in cols) priceColumnHeading(c),
      if (amountBy != null) '金額 / Amount',
    ],
    rows: [
      for (final (i, l) in lines.indexed)
        [
          i + 1, l.janCode, l.name, l.nameEn, l.maker, l.productCode, l.quantity, l.unit,
          for (final c in cols) l.price(c),
          if (amountBy != null) amount(l),
        ],
    ],
    bottom: [
      [
        '', '', '', '', '', '合計 / Total', total, '${lines.length}品目 / items',
        for (final _ in cols) '',
        if (sum != null) (sum * 100).roundToDouble() / 100,
      ],
    ],
    widths: [20, 16, 36, 34, 16, 14, 10, 14, for (final _ in cols) 14, if (amountBy != null) 16],
  );
}

/// A price column's heading on a sheet, Japanese and English.
String priceColumnHeading(PriceColumn c) => switch (c) {
      PriceColumn.cost => '原価 / Cost',
      PriceColumn.list => '定価 / List price',
      PriceColumn.sell => '販売価格 / Selling price',
      PriceColumn.ship => '単価 / Unit price',
    };

/// Every product's stock, warehouse by warehouse (0139).
Uint8List buildStockListXlsx(List<StockExportRow> rows, {String? warehouseName, DateTime? now}) {
  final fmt = DateFormat('y/MM/dd HH:mm');
  return buildXlsx(
    sheetName: '在庫一覧',
    top: [
      ['在庫一覧 / Stock list'],
      ['出力日時 / Exported', fmt.format(now ?? DateTime.now())],
      ['倉庫 / Warehouse', warehouseName ?? 'すべての倉庫 / All'],
      [],
    ],
    headers: const [
      '倉庫', '倉庫コード', 'JANコード', '商品名', '英語名', 'メーカー', '品番', '単位', '在庫数', '引当済み', '引当後の在庫', '更新日時',
    ],
    rows: [
      for (final r in rows)
        [
          r.warehouseName, r.warehouseCode, r.janCode, r.name, r.nameEn, r.maker, r.sku, r.unit, r.onHand,
          r.reserved, r.onHand - r.reserved, r.updatedAt == null ? null : fmt.format(r.updatedAt!),
        ],
    ],
    bottom: [
      ['合計', '', '${rows.length}件', '', '', '', '', '', rows.fold<int>(0, (s, r) => s + r.onHand),
        rows.fold<int>(0, (s, r) => s + r.reserved), rows.fold<int>(0, (s, r) => s + r.onHand - r.reserved)],
    ],
    widths: const [16, 10, 16, 36, 30, 16, 14, 8, 10, 10, 12, 18],
  );
}

/// A file name that says what it is: 出荷明細_OUT-000123_テスト商事_20261010.xlsx.
String shipmentSheetFileName(String number, String? to, {DateTime? now}) {
  final day = DateFormat('yyyyMMdd').format(now ?? DateTime.now());
  final who = (to ?? '').replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  final base = ['出荷明細', if (number.isNotEmpty) number else '下書き', if (who.isNotEmpty) who, day].join('_');
  return '$base.xlsx';
}
