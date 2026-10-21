import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../core/export/xlsx.dart';
import '../domain/price_book.dart';

/// 価格台帳 as one sheet: a supplier's terms for an item a row, cheapest
/// first within the item, so the sheet compares suppliers the way the
/// screen does. An item with no terms yet still gets its row.
Uint8List buildPriceBookXlsx(List<PriceBookItem> items) {
  final day = DateFormat('y/MM/dd');
  final rows = <List<Object?>>[];
  for (final i in items) {
    final item = <Object?>[
      i.janCode,
      i.itemCode,
      i.maker,
      i.name,
      i.spec,
      i.unit,
      i.category,
      i.listPrice,
    ];
    final tail = <Object?>[
      i.stock?.onHand,
      i.inMaster ? '登録済み' : '未登録',
      i.sourceFile,
    ];
    final terms = [...i.terms]
      ..sort((a, b) => (a.unitPrice ?? double.infinity).compareTo(b.unitPrice ?? double.infinity));
    if (terms.isEmpty) {
      rows.add([...item, for (var n = 0; n < 12; n++) null, ...tail]);
      continue;
    }
    for (final t in terms) {
      rows.add([
        ...item,
        t.partnerName,
        t.where,
        t.theirName,
        t.theirCode,
        t.unitPrice,
        t.listPrice,
        t.discountRate == null ? null : '${(t.discountRate! * 100).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%',
        t.caseQuantity,
        t.moq,
        t.currency,
        day.format(t.validFrom),
        t.validTo == null ? null : day.format(t.validTo!),
        ...tail,
      ]);
    }
  }
  return buildXlsx(
    sheetName: '価格台帳',
    headers: const [
      'JANコード', '品番', 'メーカー', '商品名', '規格', '単位', 'カテゴリ', '定価',
      '仕入先', '支店・倉庫', '仕入先の品名', '仕入先の品番', '仕入単価', '仕入先の定価', '掛率', '入数', '最低発注数',
      '通貨', '適用開始', '適用終了',
      '在庫数', '商品ライブラリー', '取込ファイル',
    ],
    rows: rows,
    widths: const [16, 14, 18, 40, 18, 8, 14, 10, 24, 18, 30, 16, 10, 10, 8, 8, 10, 6, 12, 12, 10, 14, 30],
  );
}
