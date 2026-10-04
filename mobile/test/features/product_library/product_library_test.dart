import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/partners/application/trading_partner_providers.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/product_library/application/product_library_providers.dart';
import 'package:wms_mobile/features/product_library/domain/product_image.dart';
import 'package:wms_mobile/features/product_library/presentation/product_gallery_screen.dart';
import 'package:wms_mobile/features/product_library/presentation/product_library_screen.dart';
import 'package:wms_mobile/features/product_library/presentation/product_thumb.dart';

import '../../support/harness.dart';

FakeProductImageRepository _repo() => FakeProductImageRepository(
      products: [
        const LibraryProduct(id: 1, name: 'ボールペン', janCode: '4901234567894', maker: 'テスト文具'),
        const LibraryProduct(id: 2, name: '消しゴム', janCode: '4900000000019', maker: 'テスト文具'),
      ],
      images: {
        1: const [
          ProductImage(id: 11, productId: 1, storagePath: '1/front.jpg', position: 1),
          ProductImage(id: 12, productId: 1, storagePath: '1/back.jpg', position: 2),
        ],
      },
    );

void main() {
  group('the face cache', () {
    test('rows asking one by one are served by one call, by id or by JAN', () async {
      final repo = _repo();
      final cache = ProductFaceCache(repo);
      cache.request(productId: 1);
      cache.request(productId: 2);
      cache.request(janCode: '4901234-567894');
      cache.request(productId: 1); // already asked
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(repo.facesCalls, 1);
      expect(repo.faceRequests.single.ids, [1, 2]);
      expect(repo.faceRequests.single.jans, ['4901234567894']);
      expect(cache.state['p:1']?.url, 'https://img.test/1/front.jpg');
      expect(cache.state['j:4901234567894']?.productId, 1);
      // Known to have none: not asked again while fresh.
      expect(cache.state['p:2']?.url, isNull);
      cache.request(productId: 2);
      await Future<void>.delayed(Duration.zero);
      expect(repo.facesCalls, 1);

      cache.invalidateProduct(1);
      expect(cache.state.containsKey('p:1'), isFalse);
      expect(cache.state.containsKey('j:4901234567894'), isFalse);
    });

    test('a JAN key ignores hyphens and spaces', () {
      expect(ProductFaceCache.keyFor(janCode: '4901234 567-894'), 'j:4901234567894');
      expect(ProductFaceCache.keyFor(productId: 3, janCode: 'x'), 'p:3');
      expect(ProductFaceCache.keyFor(janCode: ''), isNull);
    });
  });

  testWidgets('the face goes in front of the name; without one a plain box keeps its place', (tester) async {
    final repo = _repo();
    await pumpApp(
      tester,
      const Scaffold(
        body: Column(children: [
          ProductWithThumb(productId: 1, productName: 'ボールペン', child: Text('ボールペン')),
          ProductWithThumb(janCode: '4900000000019', productName: '消しゴム', child: Text('消しゴム')),
        ]),
      ),
      overrides: [productImageRepositoryProvider.overrideWithValue(repo)],
    );
    expect(find.byKey(const ValueKey('product-thumb-img-1')), findsOneWidget);
    // The second has no picture: a plain box, not an image.
    expect(find.byKey(const ValueKey('product-thumb-img-null')), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('product-thumb-4900000000019')), matching: find.byType(Image)), findsNothing);
    expect(repo.facesCalls, 1);
    final thumb = tester.getTopLeft(find.byKey(const ValueKey('product-thumb-1')));
    final name = tester.getTopLeft(find.text('ボールペン'));
    expect(thumb.dx, lessThan(name.dx));

    // Tapping the face opens the product's pictures.
    await tester.tap(find.byKey(const ValueKey('product-thumb-1')));
    await tester.pumpAndSettle();
    expect(find.byType(ProductGalleryScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('pl-image-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('pl-add-photo')), findsNothing);
  });

  testWidgets('the library lists every product with its face and can show only those without', (tester) async {
    final repo = _repo();
    await pumpApp(tester, const ProductLibraryScreen(), overrides: [productImageRepositoryProvider.overrideWithValue(repo)]);
    expect(find.byKey(const ValueKey('pl-product-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('pl-product-2')), findsOneWidget);
    expect(find.text('写真2枚'), findsOneWidget);
    expect(find.text('写真がまだありません'), findsOneWidget);
    // The list's own faces are used; no extra lookup.
    expect(repo.facesCalls, 0);

    await tester.tap(find.byKey(const ValueKey('pl-without-images')));
    await tester.pumpAndSettle();
    expect(repo.lastLibraryQuery?.withoutImages, isTrue);
    expect(find.byKey(const ValueKey('pl-product-1')), findsNothing);
    expect(find.byKey(const ValueKey('pl-product-2')), findsOneWidget);
  });

  testWidgets('a manager adds a picture to the front, makes another the face, and takes one down', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _repo();
    await pumpApp(
      tester,
      ProductGalleryScreen(
        productId: 1,
        productName: 'ボールペン',
        pickPicture: (_) async => (bytes: Uint8List.fromList([1, 2, 3]), name: 'side.jpg', contentType: 'image/jpeg'),
      ),
      overrides: [
        productImageRepositoryProvider.overrideWithValue(repo),
        productLibraryCanManageProvider.overrideWithValue(true),
      ],
    );
    expect(find.text('表紙'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pl-add-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pl-put-first')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pl-from-gallery')));
    await tester.pumpAndSettle();
    expect(repo.lastUpload, (productId: 1, fileName: 'side.jpg', first: true));
    expect(find.text('写真を追加しました'), findsOneWidget);
    final newId = repo.images[1]!.first.id;
    expect(repo.images[1]!.first.storagePath, '1/side.jpg');
    expect(find.byKey(ValueKey('pl-make-face-$newId')), findsNothing);

    // The back picture to the front.
    await tester.tap(find.byKey(const ValueKey('pl-make-face-12')));
    await tester.pumpAndSettle();
    expect(repo.reorders.last.$1, 1);
    expect(repo.reorders.last.$2, [12, newId, 11]);
    expect(repo.images[1]!.first.id, 12);

    await tester.tap(find.byKey(const ValueKey('pl-withdraw-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pl-withdraw-ok')));
    await tester.pumpAndSettle();
    expect(repo.withdrawn, [11]);
    expect(find.byKey(const ValueKey('pl-image-11')), findsNothing);
  });

  test('the library query is a value, so the same search is the same provider', () {
    final c = ProviderContainer(overrides: [productImageRepositoryProvider.overrideWithValue(_repo())]);
    addTearDown(c.dispose);
    expect(productLibraryProvider((query: 'a', withoutImages: false)), productLibraryProvider((query: 'a', withoutImages: false)));
  });

  group('the product\'s attributes (0110)', () {
    ProductProfile profile() => const ProductProfile(
          productId: 1,
          name: 'ボールペン黒',
          janCode: '4901234567894',
          sku: 'BP-01',
          attributes: [
            ProductAttributeValue(attribute: ProductAttributeDef(id: 1, key: 'color', name: '色'), value: '黒'),
            ProductAttributeValue(attribute: ProductAttributeDef(id: 2, key: 'size', name: 'サイズ')),
          ],
          suppliers: [
            SupplierProfile(
              supplierId: 7,
              supplierName: 'A商社',
              name: 'BALL PEN BK',
              code: 'BP01',
              maker: 'TEST BUNGU',
              writings: [SupplierWriting(field: 'jan', values: ['4901234-567894'], seenCount: 3)],
              attributes: [
                SupplierAttribute(attributeId: 1, key: 'color', name: '色', rawName: 'カラー', rawValue: 'BK', ourValue: '黒'),
                SupplierAttribute(attributeId: 2, key: 'size', name: 'サイズ', rawName: 'Size', rawValue: 'M'),
              ],
            ),
          ],
        );

    Future<FakeProductImageRepository> pumpTab(WidgetTester tester, int tab, {bool manage = true}) async {
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeProductImageRepository(profiles: {1: profile()});
      await pumpApp(
        tester,
        ProductGalleryScreen(productId: 1, productName: 'ボールペン黒', initialTab: tab),
        overrides: [
          productImageRepositoryProvider.overrideWithValue(repo),
          productLibraryCanManageProvider.overrideWithValue(manage),
          tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository(
              partners: const [TradingPartner(id: 7, name: 'A商社'), TradingPartner(id: 8, name: 'B商事')])),
        ],
      );
      return repo;
    }

    testWidgets('our attributes are set on the product; without the right they are read-only', (tester) async {
      final repo = await pumpTab(tester, 1);
      expect(find.descendant(of: find.byKey(const ValueKey('pl-attr-color')), matching: find.text('黒')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pl-attr-size')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('pl-attr-value')), 'L');
      await tester.tap(find.byKey(const ValueKey('pl-attr-save')));
      await tester.pumpAndSettle();
      expect(repo.lastAttributeValues, {2: 'L'});
      expect(find.descendant(of: find.byKey(const ValueKey('pl-attr-size')), matching: find.text('L')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pl-attr-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('pl-attr-new-name')), '香り');
      await tester.tap(find.byKey(const ValueKey('pl-attr-new-save')));
      await tester.pumpAndSettle();
      expect(repo.attributeDefs.last.name, '香り');
    });

    testWidgets('the master\'s product page has its photos and attributes, not its suppliers (0125)', (tester) async {
      await pumpTab(tester, 1, manage: false);
      expect(find.byKey(const ValueKey('pl-tab-photos')), findsOneWidget);
      expect(find.byKey(const ValueKey('pl-tab-attributes')), findsOneWidget);
      expect(find.byKey(const ValueKey('pl-tab-suppliers')), findsNothing);
      expect(find.text('A商社'), findsNothing);
      // The photo button belongs to the photo tab only.
      expect(find.byKey(const ValueKey('pl-add-photo')), findsNothing);
    });

    test('the profile reads from the server shape', () {
      final p = ProductProfile.fromJson(const {
        'product': {'id': 1, 'name': 'X', 'jan_code': '4901234567894'},
        'attributes': [
          {'attribute_id': 1, 'key': 'color', 'name': '色', 'value': '黒'},
        ],
        'suppliers': [
          {
            'supplier_id': 7,
            'supplier_name': 'A',
            'name': 'BALL PEN',
            'writings': [
              {'field': 'name', 'raw_values': ['BALL PEN', 'BALLPEN'], 'seen_count': 2, 'confirmed': true},
            ],
            'attributes': [
              {'attribute_id': 1, 'key': 'color', 'name': '色', 'raw_name': 'カラー', 'raw_value': 'BK', 'our_value': '黒'},
            ],
          },
        ],
      });
      expect(p.attributes.single.attribute.id, 1);
      expect(p.attributes.single.value, '黒');
      expect(p.suppliers.single.writings.single.values, ['BALL PEN', 'BALLPEN']);
      expect(p.suppliers.single.attributes.single.translated, isTrue);
    });
  });
}
