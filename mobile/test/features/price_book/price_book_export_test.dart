import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/outbound/presentation/outbound_downloads.dart';
import 'package:wms_mobile/features/price_book/application/price_book_providers.dart';
import 'package:wms_mobile/features/price_book/data/price_book_export.dart';
import 'package:wms_mobile/features/price_book/domain/price_book.dart';
import 'package:wms_mobile/features/price_book/presentation/price_book_screen.dart';
import 'package:wms_mobile/features/product/application/product_filter.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/data/product_export.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product/presentation/product_list_screen.dart';
import 'package:wms_mobile/features/supply_chain/application/supply_chain_providers.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/harness.dart';

// Synthetic items: JANs with a correct check digit, made-up names.
PriceBookTerm _term(int id, int partner, String name, double? price, {double? rate}) => PriceBookTerm(
      id: id,
      partnerId: partner,
      partnerName: name,
      unitPrice: price,
      discountRate: rate,
      validFrom: DateTime(2026, 4, 1),
    );

final _pen = PriceBookItem(
  id: 1,
  name: 'テストペン 青',
  maker: 'テスト文具',
  itemCode: 'TP-01',
  janCode: '4909999000014',
  terms: [_term(11, 4, '仕入先B', 92, rate: 0.56), _term(12, 5, '仕入先A', 88)],
  stock: const ProductStock(onHand: 40, available: 40),
);
const _note = PriceBookItem(id: 2, name: 'テストノート', maker: 'テスト紙工', janCode: '4909999000021');

void main() {
  test('the price book sheet has a row per supplier, cheapest first, and one for an item with none', () {
    final rows = readXlsx(buildPriceBookXlsx([_pen, _note]));
    expect(rows.first.take(4), ['JANコード', '品番', 'メーカー', '商品名']);
    expect(rows.length, 4);
    final supplier = rows.first.indexOf('仕入先');
    final price = rows.first.indexOf('仕入単価');
    final rate = rows.first.indexOf('掛率');
    expect([rows[1][supplier], rows[1][price]], ['仕入先A', '88']);
    expect([rows[2][supplier], rows[2][price], rows[2][rate]], ['仕入先B', '92', '56%']);
    // The JAN stays text, leading digits and all.
    expect(rows[1][0], '4909999000014');
    expect([rows[3][3], rows[3][supplier]], ['テストノート', '']);
    expect(rows[1][rows.first.indexOf('商品ライブラリー')], '未登録');
  });

  test('the product sheet has the stock in total and in each warehouse', () {
    const p = Product(
      id: 1,
      janCode: '4909999000014',
      name: 'テストペン 青',
      maker: 'テスト文具',
      stock: ProductStock(onHand: 30, reserved: 5, available: 25, warehouses: [
        WarehouseStock(warehouseId: 2, name: '第二倉庫', onHand: 30, reserved: 5, available: 25),
      ]),
    );
    final rows = readXlsx(buildProductsXlsx(
      products: [p],
      warehouses: const [(1, '本社倉庫'), (2, '第二倉庫')],
      lifecycle: (_) => '取扱中',
    ));
    final h = rows.first;
    expect(h.sublist(h.length - 2), ['在庫数(本社倉庫)', '在庫数(第二倉庫)']);
    expect(rows[1][h.indexOf('在庫数(全倉庫)')], '30');
    expect(rows[1][h.indexOf('有効在庫(全倉庫)')], '25');
    expect(rows[1].sublist(h.length - 2), ['0', '30']);
    expect(rows[1][h.indexOf('状態')], '取扱中');
  });

  testWidgets('価格台帳 saves what the search shows, or everything', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final saved = <(String, Uint8List)>[];
    await pumpApp(tester, const PriceBookScreen(), overrides: [
      priceBookSupplierViewProvider.overrideWith((_) => false),
      priceBookRepositoryProvider.overrideWithValue(FakePriceBookRepository(items: [_pen, _note])),
      saveFileProvider.overrideWithValue((n, b) async => saved.add((n, b))),
    ]);
    await tester.enterText(find.byKey(const ValueKey('cl-search')), 'ノート');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cl-export')));
    await tester.pumpAndSettle();
    expect(find.text('表示中の1件'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cl-export-shown')));
    await tester.pumpAndSettle();
    expect(saved.single.$1, startsWith('価格台帳_絞り込み_'));
    expect(readXlsx(saved.single.$2).length, 2);

    await tester.tap(find.byKey(const ValueKey('cl-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cl-export-all')));
    await tester.pumpAndSettle();
    expect(saved.last.$1, startsWith('価格台帳_全件_'));
    // Both items, the pen on a row per supplier.
    expect(readXlsx(saved.last.$2).length, 4);
    expect(find.text('2件をExcelで保存しました'), findsOneWidget);
  });

  testWidgets('商品ライブラリー saves what the filter shows, or every product', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final saved = <(String, Uint8List)>[];
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4909999000014', name: 'テストペン 青', maker: 'テスト文具'),
      Product(id: 2, janCode: '4909999000021', name: 'テストノート', maker: 'テスト紙工'),
    ]);
    final container = ProviderContainer(overrides: [
      productRepositoryProvider.overrideWithValue(repo),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
          warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本社倉庫')], totals: WarehouseTotals()))),
      scCanViewProvider.overrideWithValue(false),
      saveFileProvider.overrideWithValue((n, b) async => saved.add((n, b))),
    ]);
    addTearDown(container.dispose);
    await pumpAppWith(tester, container, const ProductListScreen());
    container.read(productFilterProvider.notifier).state = const ProductFilter(makers: {'テスト紙工'});
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pl-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pl-export-shown')));
    await tester.pumpAndSettle();
    final shown = readXlsx(saved.single.$2);
    expect(shown.length, 2);
    expect(shown[1][2], 'テストノート');
    expect(shown.first.last, '在庫数(本社倉庫)');

    await tester.tap(find.byKey(const ValueKey('pl-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pl-export-all')));
    await tester.pumpAndSettle();
    expect(saved.last.$1, startsWith('商品ライブラリー_全件_'));
    expect(readXlsx(saved.last.$2).length, 3);
    expect(find.text('2件をExcelで保存しました'), findsOneWidget);
  });
}
