import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/products/application/product_providers.dart';
import 'package:wms_mobile/features/products/data/product_repository.dart';
import 'package:wms_mobile/features/products/domain/product.dart';
import 'package:wms_mobile/features/products/presentation/product_lookup_screen.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

/// In-memory fake so the widget renders without a network.
class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository(this._all);

  final List<Product> _all;

  @override
  Future<ApiResult<List<Product>>> search({String? query, int perPage = 25}) async {
    if (query == null || query.isEmpty) return ApiSuccess(_all);
    final q = query.toLowerCase();
    final matches = _all
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            (p.barcode ?? '').contains(q))
        .toList();
    return ApiSuccess(matches);
  }

  @override
  Future<ApiResult<Product?>> lookupBarcode(String code) async =>
      const ApiSuccess<Product?>(null);

  @override
  Future<ApiResult<Product>> show(int id) async =>
      ApiSuccess(_all.firstWhere((p) => p.id == id));
}

const _products = [
  Product(
    id: 1,
    sku: 'E2E-001',
    name: 'E2E Test Product',
    barcode: '4901234500000',
    totalStock: 50,
  ),
  Product(
    id: 2,
    sku: 'LOW-002',
    name: 'Low Stock Widget',
    barcode: '4901234500017',
    totalStock: 2,
    isLowStock: true,
  ),
];

Widget _wrap(ProductRepository repo) => ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProductLookupScreen(),
      ),
    );

void main() {
  testWidgets('lists products and shows stock pills', (tester) async {
    await tester.pumpWidget(_wrap(_FakeProductRepository(_products)));
    await tester.pumpAndSettle();

    expect(find.text('E2E Test Product'), findsOneWidget);
    expect(find.text('Low Stock Widget'), findsOneWidget);
    // Stock counts surface as pill labels.
    expect(find.text('50'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('filters results when a query is submitted', (tester) async {
    await tester.pumpWidget(_wrap(_FakeProductRepository(_products)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Low');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Low Stock Widget'), findsOneWidget);
    expect(find.text('E2E Test Product'), findsNothing);
  });

  testWidgets('shows an empty state when nothing matches', (tester) async {
    await tester.pumpWidget(_wrap(_FakeProductRepository(_products)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzzznope');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.textContaining('No matches'), findsOneWidget);
  });
}
