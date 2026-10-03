import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/catalog/application/catalog_providers.dart';
import 'package:wms_mobile/features/catalog/domain/catalog.dart';
import 'package:wms_mobile/features/catalog/presentation/catalog_import_screen.dart';
import 'package:wms_mobile/features/catalog/presentation/catalog_item_screen.dart';
import 'package:wms_mobile/features/catalog/presentation/catalog_screen.dart';
import 'package:wms_mobile/features/partners/application/trading_partner_providers.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product_library/application/product_library_providers.dart';
import 'package:wms_mobile/features/product_library/data/quote_repository.dart';
import 'package:wms_mobile/features/product_library/domain/supplier_quote.dart';

import '../../support/harness.dart';

CatalogTerm _term(int id, int partner, String name, double price,
        {String? branch, String from = '2026-04-01', String? to, double? list, double? rate}) =>
    CatalogTerm(
      id: id,
      partnerId: partner,
      partnerName: name,
      branch: branch,
      unitPrice: price,
      listPrice: list,
      discountRate: rate,
      validFrom: DateTime.parse(from),
      validTo: to == null ? null : DateTime.parse(to),
    );

final _pen = CatalogItem(
  id: 1,
  name: 'サラサドライ 0.5 青',
  maker: 'ゼブラ',
  itemCode: 'JJ31-BL',
  janCode: '4901681233922',
  terms: [
    _term(11, 4, '新東光通商', 88, branch: '大阪支店', from: '2026-10-01'),
    _term(12, 5, 'アケボノクラウン', 92),
  ],
  termCount: 3,
  product: const CatalogProductRef(id: 143, name: 'サラサドライ 0.5 青', lifecycle: ProductLifecycle.active, linked: true),
  stock: const ProductStock(onHand: 40, available: 40, warehouses: [WarehouseStock(warehouseId: 1, name: 'メイン倉庫', onHand: 40, available: 40)]),
);

const _note = CatalogItem(id: 2, name: 'キャンパスノート A罫', maker: 'コクヨ', janCode: '4901480000000');

class _Reader implements QuoteRepository {
  int? partner;
  @override
  Future<ApiResult<QuoteRead>> read({int? partnerId, required MultipartFile file}) async {
    partner = partnerId;
    return const ApiSuccess(QuoteRead(partnerId: 4, lines: [
      {'jan_code': '4901681233922', 'maker': 'ゼブラ', 'product_name': 'ｻﾗｻ ﾄﾞﾗｲ 0.5 ｱｵ', 'product_code': 'JJ31-BL', 'unit_price': 90},
      {'jan_code': '4999999000017', 'maker': 'テスト', 'product_name': '新しいペン', 'list_price': 200, 'discount_rate': 0.5},
    ]));
  }

  @override
  Future<ApiResult<QuoteSaved>> save({required int partnerId, required List<Map<String, dynamic>> lines, String? note}) async =>
      const ApiSuccess(QuoteSaved());
}

void main() {
  test('a term applies within its dates, and says where', () {
    final t = _term(1, 4, 'A', 10, branch: '大阪支店', from: '2026-04-01', to: '2026-09-30');
    expect(t.appliesOn(DateTime(2026, 9, 30)), isTrue);
    expect(t.appliesOn(DateTime(2026, 10, 1)), isFalse);
    expect(t.where, '大阪支店');
    expect(_pen.cheapest!.partnerName, '新東光通商');
    expect(_pen.suppliers.map((s) => s.$2), ['新東光通商', 'アケボノクラウン']);
  });

  testWidgets('the library shows each item with its terms by supplier and branch, and its stock', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const CatalogScreen(), overrides: [
      catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository(items: [_pen, _note])),
    ]);

    expect(find.text('サラサドライ 0.5 青'), findsOneWidget);
    expect(find.text('仕入先 2社: 新東光通商 (大阪支店) ¥88 / アケボノクラウン ¥92'), findsOneWidget);
    expect(find.byKey(const ValueKey('cl-stock-1')), findsOneWidget);
    // No stock line for one not in the master.
    expect(find.byKey(const ValueKey('cl-stock-2')), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('cl-item-1')), matching: find.text('マスタ登録済み')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('cl-item-2')), matching: find.text('マスタ未登録')), findsOneWidget);
  });

  testWidgets('items are chosen, taken into the master, and deleted from the library only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeCatalogRepository(items: [_pen, _note]);
    await pumpApp(tester, const CatalogScreen(), overrides: [
      catalogRepositoryProvider.overrideWithValue(repo),
      productLibraryCanManageProvider.overrideWithValue(true),
    ]);

    // Only the ones not in the master yet.
    await tester.tap(find.byKey(const ValueKey('cl-f-notInMaster')));
    await tester.pumpAndSettle();
    expect(find.text('サラサドライ 0.5 青'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('cl-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cl-select-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cl-to-master')));
    await tester.pumpAndSettle();
    expect(repo.toMaster.single, [2]);

    await tester.tap(find.byKey(const ValueKey('cl-f-clear')));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('サラサドライ 0.5 青'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cl-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('商品マスタ・在庫・発注・入荷などには影響しません'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cl-delete-confirm')));
    await tester.pumpAndSettle();
    expect(repo.deleted.single, [1]);
    expect(find.text('サラサドライ 0.5 青'), findsNothing);
  });

  testWidgets('an item has a tab per supplier with its terms by branch, current and past', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pen = CatalogItem(
      id: 1, name: _pen.name, maker: _pen.maker, itemCode: _pen.itemCode, janCode: _pen.janCode,
      product: _pen.product, stock: _pen.stock,
      terms: [
        _term(11, 4, '新東光通商', 88, branch: '大阪支店', from: '2026-10-01'),
        _term(13, 4, '新東光通商', 85, branch: '東京支店', from: '2026-09-01'),
        _term(12, 5, 'アケボノクラウン', 92),
      ],
    );
    final repo = FakeCatalogRepository(items: [pen], history: {
      1: [
        _term(11, 4, '新東光通商', 88, branch: '大阪支店', from: '2026-10-01'),
        _term(10, 4, '新東光通商', 80, branch: '大阪支店', from: '2026-04-01', to: '2026-09-30', list: 160, rate: 0.5),
        _term(13, 4, '新東光通商', 85, branch: '東京支店', from: '2026-09-01'),
        _term(12, 5, 'アケボノクラウン', 92),
      ],
    });
    await pumpApp(tester, const CatalogItemScreen(itemId: 1), overrides: [
      catalogRepositoryProvider.overrideWithValue(repo),
      productLibraryCanManageProvider.overrideWithValue(true),
      tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository()),
    ]);

    // Overview: the parts, the master and its stock.
    expect(find.byKey(const ValueKey('cit-code')), findsOneWidget);
    expect(find.byKey(const ValueKey('cit-stock')), findsOneWidget);
    expect(find.text('新東光通商  ¥88'), findsOneWidget);
    expect(find.text('アケボノクラウン  ¥92'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cit-tab-4')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cit-where-大阪支店')), findsOneWidget);
    expect(find.byKey(const ValueKey('cit-where-東京支店')), findsOneWidget);
    // The earlier Osaka price, with its dates, marked as ended.
    expect(find.text('2026-04-01〜2026-09-30'), findsOneWidget);
    expect(find.text('終了'), findsOneWidget);
    expect(find.textContaining('定価 ¥160　掛率 50%'), findsOneWidget);

    // A new term for Osaka, by hand.
    await tester.tap(find.byKey(const ValueKey('cit-add-大阪支店')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('cit-unit_price')), '95');
    await tester.enterText(find.byKey(const ValueKey('cit-discount_rate')), '60');
    await tester.tap(find.byKey(const ValueKey('cit-save')));
    await tester.pumpAndSettle();
    final added = repo.addedTerms.single;
    expect(added.$1, 1);
    expect(added.$2['partner_id'], 4);
    expect(added.$2['branch'], '大阪支店');
    expect(added.$2['unit_price'], '95');
    expect(added.$2['discount_rate'], 0.6);
  });

  testWidgets('a file goes into the library with its supplier, branch and start date', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeCatalogRepository(items: [_pen]);
    final reader = _Reader();
    await pumpApp(
      tester,
      CatalogImportScreen(
        today: DateTime(2026, 10, 4),
        pickFile: () async => PlatformFile(name: 'mitsumori.pdf', size: 3, bytes: Uint8List.fromList([1, 2, 3])),
      ),
      overrides: [
        catalogRepositoryProvider.overrideWithValue(repo),
        fileReaderProvider.overrideWithValue(reader),
        tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository(partners: const [
          TradingPartner(id: 4, name: '新東光通商', kind: PartnerKind.supplier),
        ])),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('ci-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ci-read')));
    await tester.pumpAndSettle();

    expect(reader.partner, isNull);
    // The company on the file was chosen; one line updates an item.
    expect(find.text('ファイルに書かれた会社から判断しました'), findsOneWidget);
    expect(find.text('2行：新しい商品 1件・ライブラリーにある商品の更新 1件'), findsOneWidget);
    expect(find.text('品名 サラサ ドライ 0.5 アオ', findRichText: true), findsOneWidget);
    expect(find.text('掛率 50%', findRichText: true), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('ci-branch')), '大阪支店');
    await tester.tap(find.byKey(const ValueKey('ci-import')));
    await tester.pumpAndSettle();
    final imp = repo.imports.single;
    expect(imp.partnerId, 4);
    expect(imp.branch, '大阪支店');
    expect(imp.validFrom, DateTime(2026, 10, 4));
    expect(imp.file, 'mitsumori.pdf');
    expect(imp.lines.length, 2);
  });
}
