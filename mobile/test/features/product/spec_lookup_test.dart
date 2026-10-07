// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/data/spec_lookup.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product/presentation/spec_lookup_sheet.dart';

import '../../support/harness.dart';

class _FakeLookup implements SpecLookupRepository {
  _FakeLookup(this.answer);

  ApiResult<SpecLookupResult> answer;
  final List<SpecLookupRequest> asked = [];

  @override
  Future<ApiResult<SpecLookupResult>> lookup(SpecLookupRequest item) async {
    asked.add(item);
    return answer;
  }
}

const _product = Product(id: 7, janCode: '4902505450679', name: 'ボールペン 0.7mm', maker: 'パイロット', sku: 'LJU-10EF');

Future<FakeProductRepository> _open(WidgetTester tester, _FakeLookup lookup) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final products = FakeProductRepository(products: const [_product]);
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            key: const ValueKey('open'),
            onPressed: () => showSpecLookupSheet(context, _product),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    overrides: [
      specLookupRepositoryProvider.overrideWithValue(lookup),
      productRepositoryProvider.overrideWithValue(products),
    ],
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return products;
}

void main() {
  test('a lookup answer is read with its pages and the key it used', () {
    final r = SpecLookupResult.fromJson({
      'weight_g': 12.5,
      'weight_basis': 'product',
      'width_mm': 14,
      'depth_mm': null,
      'height_mm': '145',
      'sources': [
        {'title': '公式', 'url': 'https://maker.example/p'},
        {'url': ''},
      ],
      'confidence': 0.82,
    }, keyLabel: '調べもの', keyFallback: false);
    expect([r.weightG, r.widthMm, r.depthMm, r.heightMm], [12.5, 14.0, null, 145.0]);
    expect(r.sources.single.url, 'https://maker.example/p');
    expect(r.bestUrl, 'https://maker.example/p');
    expect([r.hasWeight, r.hasSize, r.found], [true, true, true]);
    expect(SpecLookupResult.fromJson(const {}).found, isFalse);
  });

  testWidgets('what the AI found is shown with its pages, and only what is ticked is kept, as from the web', (tester) async {
    final lookup = _FakeLookup(const ApiSuccess(SpecLookupResult(
      weightG: 12.5,
      weightBasis: 'product',
      widthMm: 14,
      depthMm: 14,
      heightMm: 145,
      sizeBasis: 'package',
      sourceUrl: 'https://maker.example/p',
      confidence: 0.8,
      note: 'メーカー公式の仕様表',
      keyLabel: '調べもの用',
    )));
    final products = await _open(tester, lookup);
    expect(lookup.asked.single.name, 'ボールペン 0.7mm');
    expect(lookup.asked.single.jan, '4902505450679');
    expect(lookup.asked.single.code, 'LJU-10EF');
    expect(find.text('重量 12.5 g'), findsOneWidget);
    expect(find.text('サイズ 幅14×奥行14×高さ145 mm'), findsOneWidget);
    expect(find.text('パッケージ込みの値'), findsOneWidget);
    expect(find.text('確からしさ 80%'), findsOneWidget);
    expect(find.text('https://maker.example/p'), findsOneWidget);
    expect(find.text('使ったキー: 調べもの用'), findsOneWidget);

    // Keep the weight only.
    await tester.tap(find.byKey(const ValueKey('sl-take-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sl-save')));
    await tester.pumpAndSettle();
    expect(products.setWeights.single.unitWeightG, 12.5);
    expect(products.setWeights.single.source, 'web');
    expect(products.setWeights.single.url, 'https://maker.example/p');
    expect(products.setWeights.single.note, startsWith('AIで調べた値（要確認）'));
    expect(products.setSizes, isEmpty);
    expect(find.text('サイズ・重量を反映しました（出どころ: Web）'), findsOneWidget);
  });

  testWidgets('nothing sure found, or the key out of quota, is said plainly and nothing can be kept', (tester) async {
    final lookup = _FakeLookup(const ApiSuccess(SpecLookupResult(keyLabel: '読み取り用', keyFallback: true)));
    await _open(tester, lookup);
    expect(find.byKey(const ValueKey('sl-none')), findsOneWidget);
    expect(find.text('調べもの用のキーが無いため、読み取り用のキー（読み取り用）で調べました'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('sl-save'))).onPressed, isNull);
  });

  testWidgets('a failed lookup can be tried again', (tester) async {
    final lookup = _FakeLookup(const ApiSuccess(SpecLookupResult(errorKind: 'quota', message: '429')));
    await _open(tester, lookup);
    expect(find.byKey(const ValueKey('sl-error')), findsOneWidget);
    lookup.answer = const ApiSuccess(SpecLookupResult(weightG: 3));
    await tester.tap(find.text('もう一度調べる'));
    await tester.pumpAndSettle();
    expect(lookup.asked.length, 2);
    expect(find.text('重量 3 g'), findsOneWidget);
  });
}
