import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
