import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../core/export/xlsx.dart';
import '../../shipment/domain/sender_profile.dart';
import '../domain/purchase_request.dart';

/// The 入荷希望リスト sent to a supplier (0140): what we would like, and
/// yellow columns for them to say whether they have it, how many, at what
/// price and when. Japanese with English beside each heading.
/// [withStock] adds our own stock figures (off by default: they are ours).
Uint8List buildPurchaseRequestXlsx({
  required List<RequestRow> lines,
  String number = '',
  String? supplierName,
  SenderProfile? sender,
  String? title,
  String? note,
  DateTime? replyBy,
  bool withStock = false,
  DateTime? now,
}) {
  final day = DateFormat('y/MM/dd');
  final top = <List<Object?>>[
    ['入荷希望リスト（在庫・お見積りのご確認） / Request for availability and quotation'],
    ['番号 / No.', number.isEmpty ? '（下書き / Draft）' : number],
    ['作成日 / Date', day.format(now ?? DateTime.now())],
    if (supplierName != null) ['宛先 / To', '$supplierName 御中'],
    if (title != null) ['件名 / Subject', title],
    if (replyBy != null) ['ご回答期限 / Reply by', day.format(replyBy)],
    if (sender != null && sender.companyName.isNotEmpty) ...[
      ['差出人 / From', sender.companyName],
      if (sender.postalCode.isNotEmpty || sender.address.isNotEmpty)
        ['住所 / Address', [if (sender.postalCode.isNotEmpty) '〒${sender.postalCode}', sender.address].join(' ').trim()],
      if (sender.phone.isNotEmpty) ['電話 / Tel', sender.phone],
      if (sender.contact.isNotEmpty) ['担当 / Contact', sender.contact],
    ],
    if (note != null) ['備考 / Note', note],
    ['お願い / Please', '黄色の欄に、在庫の有無（○・△・×）、ご用意できる数量、単価、納期をご記入のうえご返送ください。'
        ' / Please fill in the yellow columns: availability (○ △ ×), quantity, unit price and lead time.'],
    [],
  ];
  final headers = [
    'No.', 'JANコード / JAN', '品名 / Product', '英語名 / English name', 'メーカー / Maker', '品番 / Item code',
    '貴社品番 / Your code', '貴社品名 / Your name', '希望数量 / Qty wanted', '単位 / Unit',
    if (withStock) '当社在庫 / Our stock',
    '在庫の有無 / Available', 'ご用意数量 / Qty offered', '単価 / Unit price', '納期 / Lead time', '備考 / Remarks',
  ];
  final reply = headers.length - 5;
  final rows = [
    for (final (i, l) in lines.indexed)
      [
        i + 1, l.janCode, l.name, l.nameEn, l.maker, l.sku, l.supplierCode, l.supplierProductName, l.quantity, l.unit,
        if (withStock) l.onHand,
        null, null, null, null, l.note,
      ],
  ];
  final total = lines.fold<int>(0, (s, l) => s + l.quantity);
  return buildXlsx(
    sheetName: number.isEmpty ? '入荷希望' : number,
    top: top,
    headers: headers,
    rows: rows,
    flagged: {
      for (var r = 0; r < rows.length; r++)
        for (var c = reply; c < headers.length; c++) (r, c),
    },
    bottom: [
      ['', '', '${lines.length}品目 / items', '', '', '', '', '合計 / Total', total],
    ],
    widths: [
      22, 16, 34, 30, 14, 14, 14, 26, 12, 8, if (withStock) 12, 14, 14, 12, 14, 24,
    ],
  );
}

/// 入荷希望_REQ-000001_ウエダ商事_20261010.xlsx
String purchaseRequestFileName(String number, String? supplier, {DateTime? now}) {
  final day = DateFormat('yyyyMMdd').format(now ?? DateTime.now());
  final who = (supplier ?? '').replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  final base = ['入荷希望', if (number.isNotEmpty) number else '下書き', if (who.isNotEmpty) who, day].join('_');
  return '$base.xlsx';
}
