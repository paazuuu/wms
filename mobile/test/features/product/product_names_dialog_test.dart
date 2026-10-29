import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/data/market_names.dart';
import 'package:wms_mobile/features/product/data/web_photos.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product/presentation/product_detail_screen.dart';
import 'package:wms_mobile/features/product/presentation/product_names_dialog.dart';
import 'package:wms_mobile/features/product_library/application/product_library_providers.dart';

import '../../support/fake_market_name_repository.dart';
import '../../support/fake_web_photo_repository.dart';
import '../../support/harness.dart';

const _jan = '4909999000014';

void main() {
  test('a 商品名 is none when it is only the 品番, however the 品番 is written (0166)', () {
    expect(codeKey('ＵＭＲ０５Ｓ－３３'), 'UMR05S33');
    expect(sameCode('UMR05S.33', 'UMR05S 33'), isTrue);
    expect(sameCode('', ''), isFalse);
    expect(marketNameOf(const Product(id: 1, janCode: _jan, name: 'UMR05S.33', sku: 'UMR05S 33', baseName: 'UMR05S.33')), isNull);
    expect(marketNameOf(const Product(id: 1, janCode: _jan, name: 'ユニボール 0.5 黒', sku: 'UMR05S.33', baseName: 'ユニボール')),
        'ユニボール');
    expect(lacksName(const Product(id: 1, janCode: _jan, name: _jan)), isTrue);
  });

  testWidgets('the Japanese 商品名 is changed by hand, or looked up on the web and checked before saving', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final names = FakeMarketNameRepository(names: {_jan: 'ユニボール 替芯 0.5mm 青'});
    const product = Product(id: 7, janCode: _jan, name: 'UMR05S.33', sku: 'UMR05S.33', baseName: 'UMR05S.33', maker: '三菱鉛筆');
    bool? saved;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              saved = await showDialog<bool>(context: context, builder: (_) => const ProductNamesDialog(product: product)),
          child: const Text('open'),
        ),
      ),
      overrides: [marketNameRepositoryProvider.overrideWithValue(names)],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // 未登録: blank, not the 品番.
    expect(tester.widget<TextField>(find.byKey(const ValueKey('product-name-ja'))).controller!.text, '');
    await tester.tap(find.byKey(const ValueKey('product-name-search')));
    await tester.pumpAndSettle();
    expect(names.asked.single.single.code, 'UMR05S.33');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('product-name-ja'))).controller!.text, 'ユニボール 替芯 0.5mm 青');
    expect(names.setNames, isEmpty); // not until saved
    await tester.enterText(find.byKey(const ValueKey('product-name-ja')), 'ユニボール 替芯 0.5 青');
    await tester.tap(find.byKey(const ValueKey('product-name-en-save')));
    await tester.pumpAndSettle();
    expect(names.setNames, {7: 'ユニボール 替芯 0.5 青'});
    expect(saved, isTrue);
  });

  testWidgets('a picture from the web, asked for on the product (0166)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final photos = FakeWebPhotoRepository(found: {7});
    final names = FakeMarketNameRepository(names: {_jan: 'ユニボール 替芯 0.5mm 青'});
    await pumpApp(tester, const ProductDetailScreen(productId: 7), overrides: [
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: const [
        Product(id: 7, janCode: _jan, name: 'ユニボール 替芯 0.5mm 青', sku: 'UMR05S.33', maker: '三菱鉛筆'),
      ])),
      productLibraryCanManageProvider.overrideWithValue(true),
      webPhotoRepositoryProvider.overrideWithValue(photos),
      marketNameRepositoryProvider.overrideWithValue(names),
    ]);
    expect(find.text('ネットから写真を探す'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pd-web-photo')));
    await tester.pumpAndSettle();
    // No page known for it yet: its name looked up first, for the page.
    expect(names.asked, hasLength(1));
    expect(photos.calls.single.productIds, [7]);
    expect(find.textContaining('ネットの写真を追加しました'), findsOneWidget);
  });
}
