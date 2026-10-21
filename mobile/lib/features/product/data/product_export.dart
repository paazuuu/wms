import 'dart:typed_data';

import '../../../core/export/xlsx.dart';
import '../domain/product.dart';

/// 商品ライブラリー as one sheet: a product a row, with its codes, names,
/// terms, size, and its stock — the total, then each warehouse in
/// [warehouses] (id, name) on its own column, so one file serves every
/// warehouse. [lifecycle] names a product's state in the reader's language.
Uint8List buildProductsXlsx({
  required List<Product> products,
  required List<(int, String)> warehouses,
  required String Function(Product) lifecycle,
}) {
  const fixed = [
    'JANコード', '品番', '商品名', '英語名', 'メーカー', 'カテゴリ', '単位', '定価', '販売価格', '状態',
    '主な仕入先', '仕入先の品名', '仕入先の品番', '仕入単価', '掛率', '仕入先数',
    '重量(g)', '幅(mm)', '奥行(mm)', '高さ(mm)',
    '在庫数(全倉庫)', '引当(全倉庫)', '有効在庫(全倉庫)',
  ];
  final rows = <List<Object?>>[];
  for (final p in products) {
    final primary = p.suppliers.where((s) => s.isPrimary).firstOrNull ?? p.suppliers.firstOrNull;
    final st = p.stock;
    rows.add([
      p.janCode,
      p.sku,
      p.name,
      p.nameEn,
      p.maker,
      p.category,
      p.unit,
      p.listPrice,
      p.price,
      lifecycle(p),
      primary?.name,
      primary?.theirName,
      primary?.theirCode,
      primary?.unitPrice,
      primary?.discountRate == null ? null : '${_pct(primary!.discountRate!)}%',
      p.suppliers.length,
      p.unitWeightG,
      p.widthMm,
      p.depthMm,
      p.heightMm,
      st?.onHand ?? 0,
      st?.reserved ?? 0,
      st?.available ?? 0,
      for (final (id, _) in warehouses) st?.warehouses.where((w) => w.warehouseId == id).firstOrNull?.onHand ?? 0,
    ]);
  }
  return buildXlsx(
    sheetName: '商品ライブラリー',
    headers: [...fixed, for (final (_, name) in warehouses) '在庫数($name)'],
    rows: rows,
    widths: [16, 14, 40, 28, 18, 14, 8, 10, 10, 10, 22, 30, 16, 10, 8, 8, 10, 8, 8, 8, 12, 12, 12, for (final _ in warehouses) 14],
  );
}

/// 掛率 0.535 as "53.5", 0.6 as "60".
String _pct(double rate) => (rate * 100).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
