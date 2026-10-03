import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/ui/product_name.dart';
import 'package:wms_mobile/features/partners/application/trading_partner_providers.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product/presentation/product_detail_screen.dart';
import 'package:wms_mobile/features/product_library/application/product_library_providers.dart';
import 'package:wms_mobile/features/shipment/application/print_language_providers.dart';
import 'package:wms_mobile/features/shipment/data/print_language_repository.dart';
import 'package:wms_mobile/features/shipment/data/shipment_print.dart';
import 'package:wms_mobile/features/shipment/domain/carton.dart';
import 'package:wms_mobile/features/shipment/domain/label_template.dart';
import 'package:wms_mobile/features/shipment/domain/print_language.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';
import 'package:wms_mobile/features/shipment/domain/shipment_line.dart';
import 'package:wms_mobile/features/shipment/presentation/print_language_screen.dart';
import 'package:wms_mobile/features/supply_chain/application/supply_chain_providers.dart';

import '../../support/harness.dart';

const _jan = '4901681233922';

const _shipment = Shipment(
  id: 1,
  shipmentNumber: 'SHP-000123',
  customerName: 'アクメ商事',
  lines: [ShipmentLine(id: 1, janCode: _jan, productName: 'サラサドライ 0.5 青', quantity: 24)],
  cartons: [
    Carton(id: 1, cartonNo: 1, items: [CartonItem(janCode: _jan, productName: 'サラサドライ 0.5 青', quantity: 24)]),
  ],
);

const _names = {
  _jan: {'ja': 'サラサドライ 0.5 青', 'en': 'Zebra Sarasa Dry 0.5 Blue', 'zh': '斑马 Sarasa Dry 速干中性笔 0.5 蓝色'},
};

class _FakePrintLanguageRepository implements PrintLanguageRepository {
  PrintLanguage current = const PrintLanguage();
  final setLanguagesCalls = <List<String>>[];
  final words = <(String, String, String, String)>[];

  @override
  Future<ApiResult<PrintLanguage>> load() async => ApiSuccess(current);

  @override
  Future<ApiResult<PrintLanguage>> setLanguages(List<String> languages) async {
    setLanguagesCalls.add(languages);
    current = current.copyWith(languages: languages);
    return ApiSuccess(current);
  }

  @override
  Future<ApiResult<PrintLanguage>> setWord(String key, {required String ja, required String en, required String zh}) async {
    words.add((key, ja, en, zh));
    current = current.copyWith(terms: {...current.terms, key: {'ja': ja, 'en': en, 'zh': zh}});
    return ApiSuccess(current);
  }

  @override
  Future<ApiResult<Map<String, Map<String, String>>>> namesByJan(List<String> jans) async =>
      const ApiSuccess(_names);
}

void main() {
  group('PrintLanguage', () {
    test('reads the settings, and falls back to the seeded words', () {
      final p = PrintLanguage.fromJson(const {
        'languages': ['zh', 'en', 'xx'],
        'terms': {
          'qty': {'ja': '数量', 'en': 'Quantity', 'zh': '数量'},
        },
      });
      expect(p.languages, ['zh', 'en']);
      expect(p.word('qty', 'en'), 'Quantity');
      expect(p.word('delivery_note', 'zh'), '送货单');
      // 数量 is 数量 in Chinese and Japanese: printed once.
      expect(p.copyWith(languages: ['ja', 'zh', 'en']).words('qty'), ['数量', 'Quantity']);
      expect(PrintLanguage.fromJson(const {}).languages, ['ja', 'en']);
    });

    test('a product name is picked for the screen language', () {
      const names = {'ja': 'サラサ', 'en': 'Sarasa', 'zh': '斑马 Sarasa'};
      expect(productNameIn('zh', 'サラサ', names: names), '斑马 Sarasa');
      expect(productNameIn('zh', 'サラサ', nameEn: 'Sarasa'), 'Sarasa');
      expect(productNameIn('en', 'ｻﾗｻ'), 'サラサ');
      expect(productNameIn('ja', 'サラサ', names: names), 'サラサ');
      expect(productNamesFromJson(const {'en': 'A', 'zh': ' ', 'ja': null}), {'en': 'A'});
    });
  });

  group('printing in the chosen languages', () {
    test('the default prints Japanese with English beneath, as before', () {
      const printer = ShipmentPrinter(namesByJan: _names);
      final html = printer.deliverySlipHtml(_shipment);
      expect(html, contains('数量<span class="en">Qty</span>'));
      expect(html, contains('サラサドライ 0.5 青<span class="en">Zebra Sarasa Dry 0.5 Blue</span>'));
      expect(html, contains('御中'));
      expect(html, isNot(contains('送货单')));
    });

    test('Chinese first puts Chinese words and names on the main line', () {
      const printer = ShipmentPrinter(
        language: PrintLanguage(languages: ['zh', 'en']),
        namesByJan: _names,
      );
      final slip = printer.deliverySlipHtml(_shipment);
      expect(slip, contains('送货单<span class="en">DELIVERY NOTE</span>'));
      expect(slip, contains('斑马 Sarasa Dry 速干中性笔 0.5 蓝色<span class="en">Zebra Sarasa Dry 0.5 Blue</span>'));
      expect(slip, isNot(contains('御中')));
      expect(slip, isNot(contains('サラサ')));
      expect(printer.overallHtml(_shipment), contains('出库清单 / Shipping List'));

      final label = printer.cartonLabelValues(_shipment, _shipment.cartons.first);
      final rows = LabelTemplates.carton.render(label);
      expect(rows, contains('出库 Shipment SHP-000123'));
      expect(rows, contains('数量 Qty 24'));
      expect(rows, contains('斑马 Sarasa Dry 速干中性笔 0.5 蓝色 / Zebra Sarasa Dry 0.5 Blue'));
      // No lot: the lot row goes, its word with it.
      expect(rows.any((r) => r.contains('批次')), isFalse);
    });

    test('a product without a name in a language is printed in the others', () {
      const printer = ShipmentPrinter(language: PrintLanguage(languages: ['zh']));
      expect(printer.productNames(_jan, 'サラサドライ 0.5 青'), ['サラサドライ 0.5 青']);
    });

    test('a row of label words alone is kept', () {
      const t = LabelTemplate(id: 't', name: 't', lines: ['{{t_label_items}}', '{{t_label_lot}} {{lot}}']);
      expect(t.render({'t_label_items': '品目 items'}), ['品目 items']);
    });
  });

  testWidgets('the print languages are chosen in order and saved', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FakePrintLanguageRepository();
    await pumpApp(tester, const PrintLanguageScreen(),
        overrides: [printLanguageRepositoryProvider.overrideWithValue(repo)]);

    // Japanese, then English, as seeded.
    expect(find.textContaining('数量 / Qty'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pl-lang-ja')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pl-lang-zh')));
    await tester.pump();
    expect(find.textContaining('Qty / 数量'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pl-save-langs')));
    await tester.pumpAndSettle();
    expect(repo.setLanguagesCalls.single, ['en', 'zh']);

    await tester.tap(find.byKey(const ValueKey('pl-word-qty')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pl-word-en')), 'Quantity');
    await tester.tap(find.byKey(const ValueKey('pl-word-save')));
    await tester.pumpAndSettle();
    expect(repo.words.single, ('qty', '数量', 'Quantity', '数量'));
  });

  testWidgets('a product shows its names and its Chinese name is set', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const product = Product(
      id: 143,
      janCode: _jan,
      name: 'サラサドライ 0.5 青',
      nameEn: 'Zebra Sarasa Dry 0.5 Blue',
      names: {'ja': 'サラサドライ 0.5 青', 'en': 'Zebra Sarasa Dry 0.5 Blue'},
      baseUom: Uom(code: 'PCS', name: '本'),
    );
    final repo = FakeProductRepository(products: [product]);
    final container = ProviderContainer(overrides: [
      productRepositoryProvider.overrideWithValue(repo),
      tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository()),
      scCanViewProvider.overrideWithValue(false),
    ]);
    addTearDown(container.dispose);
    // The harness turns product management off; this one manages.
    await pumpAppWith(
      tester,
      container,
      ProviderScope(
        overrides: [productLibraryCanManageProvider.overrideWithValue(true)],
        child: const ProductDetailScreen(productId: 143),
      ),
    );

    expect(find.byKey(const ValueKey('product-name-row-en')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('product-names')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('product-name-zh')), '斑马 速干中性笔 0.5 蓝色');
    await tester.tap(find.byKey(const ValueKey('product-name-en-save')));
    await tester.pumpAndSettle();

    // Only what changed is saved.
    final saved = repo.setNames.single;
    expect(saved.productId, 143);
    expect(saved.lang, 'zh');
    expect(saved.name, '斑马 速干中性笔 0.5 蓝色');
  });

  testWidgets('the product screen lists maker, name, item code, JAN and attributes as one table', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const product = Product(
      id: 143, janCode: _jan, name: 'サラサドライ 0.5 青', maker: 'ゼブラ', sku: 'JJ31-BL',
      baseName: 'サラサドライ', unit: '本', listPrice: 165,
      attributes: [ProductPart(key: 'size', name: 'サイズ', value: '0.5'), ProductPart(key: 'color', name: '色', value: '青')],
      suppliers: [ProductSupplierRef(id: 4, name: '新東光通商')],
      baseUom: Uom(code: 'PCS', name: '本'),
    );
    final container = ProviderContainer(overrides: [
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: [product])),
      tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository()),
      scCanViewProvider.overrideWithValue(false),
    ]);
    addTearDown(container.dispose);
    await pumpAppWith(tester, container, const ProductDetailScreen(productId: 143));

    String valueOf(String key) {
      final row = find.byKey(ValueKey(key));
      return tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))).last.data!;
    }

    expect(find.text('基本情報'), findsOneWidget);
    expect(valueOf('pd-maker'), 'ゼブラ');
    expect(valueOf('pd-base-name'), 'サラサドライ');
    expect(valueOf('pd-code'), 'JJ31-BL');
    expect(valueOf('pd-jan'), _jan);
    expect(valueOf('pd-attr-color'), '青');
    expect(valueOf('pd-attr-size'), '0.5');
    expect(valueOf('pd-list-price'), '¥165');
    expect(valueOf('pd-suppliers'), '新東光通商');
  });
}
