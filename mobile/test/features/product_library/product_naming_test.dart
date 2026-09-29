import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/notation/domain/notation.dart';
import 'package:wms_mobile/features/product_library/application/product_library_providers.dart';
import 'package:wms_mobile/features/product_library/application/product_naming_providers.dart';
import 'package:wms_mobile/features/product_library/domain/product_image.dart';
import 'package:wms_mobile/features/product_library/domain/product_naming.dart';
import 'package:wms_mobile/features/product_library/presentation/name_formats_screen.dart';
import 'package:wms_mobile/features/product_library/presentation/product_naming_dialog.dart';
import 'package:wms_mobile/features/product_library/presentation/register_products_sheet.dart';

import '../../support/harness.dart';

const _proposals = [
  ProductProposal(
    row: 2,
    janCode: '4902505000001',
    maker: '三菱鉛筆',
    code: 'UBA-188',
    baseName: 'ユニボール エア',
    unit: '本',
    listPrice: 200,
    attributes: {'size': '0.5mm', 'color': '赤'},
    source: {'product_name': 'ﾕﾆﾎﾞｰﾙ ｴｱ 0.5MM ｱｶ'},
  ),
  ProductProposal(
    row: 3,
    janCode: '4901480000002',
    maker: 'コクヨ',
    code: 'KE-WS30',
    baseName: 'KE-WS30',
    baseFromCode: true,
  ),
];

void main() {
  group('a name built from its parts', () {
    test('placeholders are filled; empty ones and empty brackets go', () {
      expect(
        renderProductName('{maker} {base} {attr:size} {attr:color}',
            base: 'ユニボール エア', maker: '三菱鉛筆', attributes: const {'size': '0.5mm', 'color': '赤'}),
        '三菱鉛筆 ユニボール エア 0.5mm 赤',
      );
      expect(renderProductName('{base} {attr:size} {attr:color} ({code})', base: 'ノート'), 'ノート');
      expect(renderProductName('{base}  ({code})', base: 'ノート', code: 'N-1'), 'ノート (N-1)');
      expect(renderProductName('{base}【{unit}】', base: 'ノート', unit: '冊'), 'ノート【冊】');
    });

    test('a proposal from the database, corrected by a person', () {
      final p = ProductProposal.fromJson(const {
        'row': 4,
        'jan_code': '4900000000019',
        'maker': 'コクヨ',
        'code': 'KE-WS30',
        'base_name': 'KE-WS30',
        'base_from_code': true,
        'unit': '冊',
        'list_price': '910',
        'attributes': {'color': '水色', 'size': ''},
        'name': 'KE-WS30 水色',
        'source': {'product_code': 'KE-WS30'},
      });
      expect(p.baseFromCode, isTrue);
      expect(p.listPrice, 910);
      expect(p.attributes, {'color': '水色'});
      expect(p.complete, isTrue);

      final named = p.copyWith(baseName: 'キャンパスノート');
      expect(named.baseFromCode, isFalse);
      final json = named.toRegisterJson();
      expect(json['base_name'], 'キャンパスノート');
      expect(json['source'], {'product_code': 'KE-WS30'});
      expect(p.copyWith(clearListPrice: true).listPrice, isNull);
      expect(p.copyWith(maker: ' ').complete, isFalse);
    });

    test('a read line carries 単位, 定価 and the supplier code to learn and propose', () {
      final l = ReadLineResult.fromJson(const {
        'row': 5,
        'raw_jan_code': '4901-480',
        'jan_code': '4901480000002',
        'product_code': 'KE-WS30',
        'supplier_code': '934953',
        'unit': 'ｻﾂ',
        'unit_price': '41.6',
        'list_price': 910,
        'planned_quantity': 3,
      });
      expect(l.unit, 'ｻﾂ');
      expect(l.unitPrice, 41.6);
      expect(l.listPrice, 910);
      final learn = l.toLearnJson();
      expect(learn['supplier_code'], '934953');
      expect(learn['list_price'], 910);
      final propose = l.toProposeJson();
      expect(propose['row'], 5);
      expect(propose['jan_code'], '4901480000002');
      expect(propose['unit'], 'ｻﾂ');
      // A line tied to a product keeps them.
      final tied = l.withProduct(const ResolvedProduct(id: 1, janCode: '4901480000002', name: 'ノート'));
      expect(tied.supplierCode, '934953');
    });
  });

  group('商品様式', () {
    testWidgets('a format is edited with its parts; saving says how many names were rebuilt', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeProductNamingRepository();
      await pumpApp(tester, const NameFormatsScreen(),
          overrides: [productNamingRepositoryProvider.overrideWithValue(repo)]);

      expect(find.text('標準'), findsOneWidget);
      expect(find.text('既定'), findsOneWidget);
      // Each format with an example of what it makes.
      expect(find.text('ボールペン 0.5mm 赤'), findsOneWidget);
      expect(find.text('サンプル文具 ボールペン 0.5mm 赤'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nf-format-1')));
      await tester.pumpAndSettle();
      // What the real products using it would be called.
      expect(find.byKey(const ValueKey('nf-preview-1')), findsOneWidget);
      // The maker goes in front: put the cursor at the start, tap メーカー.
      final field = find.byKey(const ValueKey('nf-template'));
      await tester.enterText(field, '{base} {attr:size} {attr:color}');
      final ctl = tester.widget<TextField>(field).controller!;
      ctl.selection = const TextSelection.collapsed(offset: 0);
      await tester.tap(find.byKey(const ValueKey('nf-insert-{maker}')));
      await tester.pumpAndSettle();
      expect(ctl.text, '{maker}{base} {attr:size} {attr:color}');
      await tester.enterText(field, '{maker} {base} {attr:size} {attr:color} ({code})');
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('nf-sample'))).data, 'サンプル文具 ボールペン 0.5mm 赤 (BP-05)');
      await tester.tap(find.byKey(const ValueKey('nf-preview')));
      await tester.pumpAndSettle();
      expect(repo.lastPreviewTemplate, '{maker} {base} {attr:size} {attr:color} ({code})');

      await tester.tap(find.byKey(const ValueKey('nf-save')));
      await tester.pumpAndSettle();
      expect(repo.lastSaved?.id, 1);
      expect(repo.lastSaved?.template, '{maker} {base} {attr:size} {attr:color} ({code})');
      expect(find.text('保存しました。3件の商品名を作り直しました'), findsOneWidget);
    });

    testWidgets('a format without the base name is not saved', (tester) async {
      final repo = FakeProductNamingRepository();
      await pumpApp(tester, const NameFormatsScreen(),
          overrides: [productNamingRepositoryProvider.overrideWithValue(repo)]);
      await tester.tap(find.byKey(const ValueKey('nf-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('nf-name')), '品番だけ');
      await tester.enterText(find.byKey(const ValueKey('nf-template')), '{code}');
      await tester.tap(find.byKey(const ValueKey('nf-save')));
      await tester.pumpAndSettle();
      expect(repo.lastSaved, isNull);
      expect(find.text('組み立て方に「基本名」を入れてください'), findsOneWidget);
    });

    testWidgets('a maker is renamed everywhere', (tester) async {
      final repo = FakeProductNamingRepository();
      await pumpApp(tester, const NameFormatsScreen(),
          overrides: [productNamingRepositoryProvider.overrideWithValue(repo)]);
      await tester.tap(find.byKey(const ValueKey('nf-tab-makers')));
      await tester.pumpAndSettle();
      expect(find.text('ミツビシ'), findsOneWidget);
      expect(find.text('5件の商品 · 別表記1件'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nf-maker-7')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('nf-maker-name')), '三菱鉛筆');
      await tester.tap(find.byKey(const ValueKey('nf-maker-save')));
      await tester.pumpAndSettle();
      expect(repo.lastMakerRename, (7, '三菱鉛筆'));
      expect(find.text('5件の商品に反映しました'), findsOneWidget);
      expect(find.text('三菱鉛筆'), findsOneWidget);
    });

    testWidgets('a colour is called something else everywhere', (tester) async {
      final repo = FakeProductNamingRepository();
      await pumpApp(tester, const NameFormatsScreen(),
          overrides: [productNamingRepositoryProvider.overrideWithValue(repo)]);
      await tester.tap(find.byKey(const ValueKey('nf-tab-values')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nf-value-attr')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('色').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('nf-value-from')), '赤');
      await tester.enterText(find.byKey(const ValueKey('nf-value-to')), 'レッド');
      await tester.tap(find.byKey(const ValueKey('nf-value-save')));
      await tester.pumpAndSettle();
      expect(repo.lastValueRename, (1, '赤', 'レッド'));
      expect(find.text('2件の商品を変更しました'), findsOneWidget);
    });
  });

  group('a product name', () {
    Future<FakeProductNamingRepository> open(WidgetTester tester, ProductNaming n) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeProductNamingRepository(namings: {n.id: n});
      final images = FakeProductImageRepository(profiles: {
        n.id: ProductProfile(productId: n.id, name: n.name, attributes: const [
          ProductAttributeValue(attribute: ProductAttributeDef(id: 1, key: 'color', name: '色'), value: '赤'),
          ProductAttributeValue(attribute: ProductAttributeDef(id: 2, key: 'size', name: 'サイズ'), value: '0.5mm'),
        ]),
      });
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(context: context, builder: (_) => ProductNamingDialog(productId: n.id)),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: [
          productNamingRepositoryProvider.overrideWithValue(repo),
          productImageRepositoryProvider.overrideWithValue(images),
        ],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('is built from its parts as they are typed', (tester) async {
      final repo = await open(tester, const ProductNaming(id: 3, name: 'ﾕﾆﾎﾞｰﾙ ｴｱ 0.5MM ｱｶ', maker: '三菱鉛筆', sku: 'UBA-188'));
      // A product from before 0111 has no parts yet.
      expect(find.text('この商品はまだ部品に分かれていません。基本名を入れると様式で名前が作られます。'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('pn-base')), 'ユニボール エア');
      await tester.enterText(find.byKey(const ValueKey('pn-unit')), '本');
      await tester.enterText(find.byKey(const ValueKey('pn-price')), '200');
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('pn-preview'))).data, 'ユニボール エア 0.5mm 赤');
      // Another format: the maker in front.
      await tester.tap(find.byKey(const ValueKey('pn-format')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('メーカー名つき').last);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('pn-preview'))).data, '三菱鉛筆 ユニボール エア 0.5mm 赤');
      await tester.tap(find.byKey(const ValueKey('pn-save')));
      await tester.pumpAndSettle();
      final (id, draft) = repo.lastNaming!;
      expect(id, 3);
      expect(draft.baseName, 'ユニボール エア');
      expect(draft.unit, '本');
      expect(draft.listPrice, 200);
      expect(draft.formatId, 2);
      expect(draft.manual, isFalse);
      expect(find.byType(ProductNamingDialog), findsNothing);
    });

    testWidgets('can be typed by hand instead', (tester) async {
      final repo = await open(tester, const ProductNaming(id: 4, name: 'ノート', baseName: 'ノート'));
      await tester.tap(find.byKey(const ValueKey('pn-manual')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('pn-name')), '特注ノート（社名入り）');
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('pn-preview'))).data, '特注ノート（社名入り）');
      await tester.tap(find.byKey(const ValueKey('pn-save')));
      await tester.pumpAndSettle();
      expect(repo.lastNaming!.$2.manual, isTrue);
      expect(repo.lastNaming!.$2.toJson()['name'], '特注ノート（社名入り）');
    });
  });

  group('registering from a document', () {
    Future<(FakeProductNamingRepository, List<RegisteredProduct>?)> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeProductNamingRepository(proposals: [..._proposals]);
      List<RegisteredProduct>? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showRegisterProductsSheet(context, partnerId: 9, lines: const [
                {'row': 2, 'product_name': 'ﾕﾆﾎﾞｰﾙ ｴｱ 0.5MM ｱｶ'},
              ]),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: [productNamingRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (repo, result);
    }

    testWidgets('proposals in our format are checked, corrected and registered', (tester) async {
      final (repo, _) = await open(tester);
      expect(repo.lastProposePartner, 9);
      expect(repo.lastProposeLines?.single['row'], 2);
      // Tidied, size and colour taken out into attributes.
      expect(tester.widget<Text>(find.byKey(const ValueKey('rp-name-2'))).data, 'ユニボール エア 0.5mm 赤');
      expect(find.byKey(const ValueKey('rp-attr-2-size')), findsOneWidget);
      expect(find.text('サイズ: 0.5mm'), findsOneWidget);
      // The PDF had no name: the 品番 stands in, and says so.
      expect(find.byKey(const ValueKey('rp-from-code-3')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('rp-base-3')), 'キャンパス ルーズリーフ');
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('rp-name-3'))).data, 'キャンパス ルーズリーフ');
      expect(find.byKey(const ValueKey('rp-from-code-3')), findsNothing);
      // The colour is not wanted in the name.
      await tester.tap(find.byKey(const ValueKey('rp-attr-drop-2-color')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('rp-name-2'))).data, 'ユニボール エア 0.5mm');

      expect(find.text('2件を登録'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rp-register')));
      await tester.pumpAndSettle();
      expect(repo.lastRegistered?.length, 2);
      expect(repo.lastRegistered?.last.baseName, 'キャンパス ルーズリーフ');
      expect(repo.lastRegistered?.first.attributes, {'size': '0.5mm'});
      expect(repo.lastRegistered?.first.source, {'product_name': 'ﾕﾆﾎﾞｰﾙ ｴｱ 0.5MM ｱｶ'});
      expect(find.byType(RegisterProductsSheet), findsNothing);
    });

    testWidgets('only the chosen ones are registered, and each needs a maker', (tester) async {
      final (repo, _) = await open(tester);
      await tester.tap(find.byKey(const ValueKey('rp-choose-3')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('rp-maker-2')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rp-register')));
      await tester.pumpAndSettle();
      expect(repo.lastRegistered, isNull);
      expect(find.text('選んだ商品にはメーカーと基本名が必要です'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('rp-maker-2')), '三菱鉛筆');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rp-register')));
      await tester.pumpAndSettle();
      expect(repo.lastRegistered?.single.janCode, '4902505000001');
    });
  });
}
