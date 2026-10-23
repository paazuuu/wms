// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/data/spec_lookup.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product/presentation/bulk_weight_screen.dart';

import '../../support/harness.dart';

class _Lookup implements SpecLookupRepository {
  _Lookup(this.byJan, {this.searchUnavailable = false});
  final Map<String, SpecLookupResult> byJan;
  final bool searchUnavailable;
  final batches = <List<String?>>[];

  @override
  Future<ApiResult<SpecLookupResult>> lookup(SpecLookupRequest item) async => throw UnimplementedError();

  @override
  Future<ApiResult<SpecLookupBatch>> lookupMany(List<SpecLookupRequest> items) async {
    batches.add([for (final i in items) i.jan]);
    return ApiSuccess((
      results: [for (final i in items) byJan[i.jan] ?? const SpecLookupResult(errorKind: 'parse')],
      searchUnavailable: searchUnavailable,
    ));
  }
}

String _jan(int i) => '49099990001${i.toString().padLeft(2, '0')}';

void main() {
  testWidgets('every product in use without a weight is looked up five at a time; only what is ticked is kept',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final products = FakeProductRepository(products: [
      for (var i = 1; i <= 7; i++) Product(id: i, janCode: _jan(i), name: '商品$i', maker: 'テスト'),
      Product(id: 8, janCode: _jan(8), name: '重さあり', unitWeightG: 10),
      Product(id: 9, janCode: _jan(9), name: '取扱終了', status: 'inactive'),
    ]);
    final lookup = _Lookup({
      _jan(1): const SpecLookupResult(weightG: 12, confidence: 0.9, sourceUrl: 'https://maker.example/1'),
      _jan(2): const SpecLookupResult(weightG: 7, confidence: 0.4, estimated: true),
      _jan(6): const SpecLookupResult(weightG: 30, confidence: 0.5, sourceUrl: 'https://shop.example/6'),
    }, searchUnavailable: true);
    await pumpApp(tester, const BulkWeightScreen(), overrides: [
      productRepositoryProvider.overrideWithValue(products),
      specLookupRepositoryProvider.overrideWithValue(lookup),
    ]);
    expect(find.text('重さが未登録: 7件'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bw-start')));
    await tester.pumpAndSettle();
    expect(lookup.batches.map((b) => b.length), [5, 2]);
    expect(lookup.batches.expand((b) => b), isNot(contains(_jan(8))));
    expect(lookup.batches.expand((b) => b), isNot(contains(_jan(9))));
    expect(find.text('7/7件 調べました'), findsOneWidget);
    expect(find.byKey(const ValueKey('bw-estimates')), findsOneWidget);

    // Sure and from the web: ticked. An estimate or a doubtful one: not.
    bool? ticked(int id) => tester.widget<Checkbox>(find.byKey(ValueKey('bw-tick-$id'))).value;
    expect(ticked(1), isTrue);
    expect(ticked(2), isFalse);
    expect(ticked(6), isFalse);
    expect(find.descendant(of: find.byKey(const ValueKey('bw-row-2')), matching: find.text('推定')), findsOneWidget);
    expect(find.byKey(const ValueKey('bw-none-3')), findsOneWidget);
    expect(find.text('チェックした1件を反映'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bw-tick-6')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bw-save')));
    await tester.pumpAndSettle();
    expect([for (final w in products.setWeights) (w.productId, w.unitWeightG, w.source)], [(1, 12.0, 'web'), (6, 30.0, 'web')]);
    expect(find.text('2件の重さを反映しました'), findsOneWidget);
  });

  testWidgets('out of quota stops at once and says what to do', (tester) async {
    final products = FakeProductRepository(products: [
      for (var i = 1; i <= 7; i++) Product(id: i, janCode: _jan(i), name: '商品$i'),
    ]);
    final lookup = _Lookup({for (var i = 1; i <= 7; i++) _jan(i): const SpecLookupResult(errorKind: 'quota')});
    await pumpApp(tester, const BulkWeightScreen(), overrides: [
      productRepositoryProvider.overrideWithValue(products),
      specLookupRepositoryProvider.overrideWithValue(lookup),
    ]);
    await tester.tap(find.byKey(const ValueKey('bw-start')));
    await tester.pumpAndSettle();
    expect(lookup.batches.length, 1);
    expect(find.byKey(const ValueKey('bw-error')), findsOneWidget);
    expect(find.textContaining('有料プラン'), findsWidgets);
  });
}
