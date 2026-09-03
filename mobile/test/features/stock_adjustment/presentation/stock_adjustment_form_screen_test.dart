import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/products/domain/product.dart';
import 'package:wms_mobile/features/stock_adjustment/application/stock_adjustment_providers.dart';
import 'package:wms_mobile/features/stock_adjustment/data/stock_adjustment_repository.dart';
import 'package:wms_mobile/features/stock_adjustment/domain/adjustment_type.dart';
import 'package:wms_mobile/features/stock_adjustment/domain/stock_adjustment.dart';
import 'package:wms_mobile/features/stock_adjustment/presentation/stock_adjustment_form_screen.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

/// Captures the last create() call so the test can assert the signed quantity
/// and type sent to the API.
class _FakeStockAdjustmentRepository implements StockAdjustmentRepository {
  int? lastQuantity;
  String? lastType;

  @override
  Future<ApiResult<StockAdjustment>> create({
    required int productId,
    required int quantity,
    required String type,
    String? reason,
    String? notes,
  }) async {
    lastQuantity = quantity;
    lastType = type;
    return ApiSuccess(
      StockAdjustment(
        id: 1,
        productId: productId,
        type: AdjustmentType.fromWire(type),
        quantityBefore: 50,
        quantityAfter: 50 + quantity,
        adjustmentQuantity: quantity,
      ),
    );
  }
}

const _product = Product(
  id: 1,
  sku: 'E2E-001',
  name: 'E2E Test Product',
  totalStock: 50,
);

Widget _wrap(StockAdjustmentRepository repo) => ProviderScope(
      overrides: [
        stockAdjustmentRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StockAdjustmentFormScreen(product: _product),
      ),
    );

/// Hosts the form under a landing screen so a successful adjustment can pop
/// back to a real route (mirrors being pushed from the search screen).
Widget _wrapPushed(StockAdjustmentRepository repo) => ProviderScope(
      overrides: [
        stockAdjustmentRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const StockAdjustmentFormScreen(product: _product),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('previews the resulting on-hand as the quantity is typed',
      (tester) async {
    await tester.pumpWidget(_wrap(_FakeStockAdjustmentRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '3');
    await tester.pumpAndSettle();

    // Add is the default direction: 50 + 3.
    expect(find.text('50 → 53'), findsOneWidget);
  });

  testWidgets('submits a signed removal and reports the new on-hand',
      (tester) async {
    final repo = _FakeStockAdjustmentRepository();
    await tester.pumpWidget(_wrapPushed(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Switch to Remove, then enter 4.
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '4');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove stock'));
    await tester.pumpAndSettle();

    expect(repo.lastQuantity, -4);
    expect(repo.lastType, 'manual');
    expect(find.textContaining('now 46 on hand'), findsOneWidget);
  });

  testWidgets('rejects a zero quantity with a message', (tester) async {
    final repo = _FakeStockAdjustmentRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add stock'));
    await tester.pumpAndSettle();

    expect(repo.lastQuantity, isNull);
    expect(find.textContaining('greater than zero'), findsOneWidget);
  });
}
