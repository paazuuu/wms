import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/product/application/product_filter.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/data/product_category_repository.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product/presentation/product_categories_screen.dart';

import '../../support/fake_product_category_repository.dart';
import '../../support/harness.dart';

Product _p(int id, String jan, String name, {String? category}) =>
    Product(id: id, janCode: jan, name: name, category: category, maker: 'テスト文具');

void main() {
  test('a path typed any way; each level of it; what is under a level', () {
    expect(parseCategoryPath('文房具>ペン ＞ ボールペン / 油性'), ['文房具', 'ペン', 'ボールペン', '油性']);
    expect(parseCategoryPath('  '), isEmpty);
    expect(categoryLevels('文房具 > ペン > ボールペン'), ['文房具', '文房具 > ペン', '文房具 > ペン > ボールペン']);
    expect(inCategory('文房具 > ペン > ボールペン', '文房具 > ペン'), isTrue);
    expect(inCategory('文房具 > ペンケース', '文房具 > ペン'), isFalse, reason: 'a level, not a prefix of words');
    expect(inCategory(null, '文房具'), isFalse);
  });

  test('the filter: a level takes in everything under it, counted at every level', () {
    final products = [
      _p(1, '4909999000014', 'テストペン 青', category: '文房具 > ペン > ボールペン > 油性'),
      _p(2, '4909999000021', 'テストシャープ', category: '文房具 > ペン > シャープペン'),
      _p(3, '4909999000038', 'テスト消しゴム', category: '文房具 > 消しゴム'),
      _p(4, '4909999000045', 'テストかご'),
    ];
    final facets = ProductFacets.of(products);
    expect(facets.categories['文房具'], 3);
    expect(facets.categories['文房具 > ペン'], 2);
    expect(facets.categories['文房具 > ペン > ボールペン > 油性'], 1);
    const pens = ProductFilter(categories: {'文房具 > ペン'});
    expect([for (final p in products) if (pens.matches(p)) p.id], [1, 2]);
  });

  testWidgets('商品カテゴリー: the tree with its counts; those with none placed by the AI', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cats = FakeProductCategoryRepository(
      nodes: const [
        CategoryNode(id: 1, path: ['文房具'], total: 2),
        CategoryNode(id: 2, parentId: 1, path: ['文房具', 'ペン'], total: 2),
        CategoryNode(id: 3, parentId: 2, path: ['文房具', 'ペン', 'ボールペン'], products: 2, total: 2),
        CategoryNode(id: 4, parentId: 2, path: ['文房具', 'ペン', '水性'], total: 0),
      ],
      paths: {'4909999000021': ['文房具', 'ノート']},
    );
    final products = FakeProductRepository(products: [
      _p(1, '4909999000014', 'テストペン 青', category: '文房具 > ペン > ボールペン'),
      _p(2, '4909999000021', 'テストノート'),
    ]);
    await pumpApp(tester, const ProductCategoriesScreen(canManage: true), overrides: [
      productCategoryRepositoryProvider.overrideWithValue(cats),
      productRepositoryProvider.overrideWithValue(products),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pc-node-3')), findsOneWidget);
    // A level nothing sits under is not listed.
    expect(find.byKey(const ValueKey('pc-node-4')), findsNothing);
    // Deeper levels sit further in.
    expect(tester.getTopLeft(find.text('ボールペン')).dx, greaterThan(tester.getTopLeft(find.text('文房具')).dx));

    await tester.tap(find.byKey(const ValueKey('pc-classify')));
    await tester.pumpAndSettle();
    // Only the product with no category was asked about.
    expect(cats.asked.map((a) => a.productId), [2]);
    expect(cats.applied.single.$2, ['文房具', 'ノート']);
    expect(find.text('1件中 1件にカテゴリーを付けました'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pc-rename-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pc-rename-field')), '筆記具');
    await tester.tap(find.byKey(const ValueKey('pc-rename-ok')));
    await tester.pumpAndSettle();
    expect(cats.renamed, [(2, '筆記具')]);
  });
}
