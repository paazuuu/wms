import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/inventory/application/inventory_providers.dart';
import 'package:wms_mobile/features/inventory/domain/stock_discrepancy.dart';
import 'package:wms_mobile/features/inventory/presentation/stock_reconciliation_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeInventoryRepository repo, {
  int? warehouseId = 1,
}) async {
  final container = ProviderContainer(overrides: [
    inventoryRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  if (warehouseId != null) {
    container.read(activeWarehouseIdProvider.notifier).state = warehouseId;
  }
  await pumpAppWith(tester, container, const StockReconciliationScreen());
  return container;
}

void main() {
  group('StockReconciliationScreen', () {
    testWidgets('shows a quantity drift with its levels, units and diff',
        (tester) async {
      final repo = FakeInventoryRepository(discrepancies: const [
        StockDiscrepancy(
          warehouseId: 1,
          janCode: '4901234567890',
          productId: 7,
          stockLevelsOnHand: 100,
          stockUnitsOnHand: 90,
          reason: 'quantity drift',
        ),
      ]);

      await _pump(tester, repo);

      expect(find.text('4901234567890'), findsOneWidget);
      expect(find.text('在庫水準 100'), findsOneWidget);
      expect(find.text('実在庫 90'), findsOneWidget);
      expect(find.text('差分 +10'), findsOneWidget);
    });

    testWidgets('an unlinked JAN reads as its own reason, with no product to tap',
        (tester) async {
      final repo = FakeInventoryRepository(discrepancies: const [
        StockDiscrepancy(
          warehouseId: 1,
          janCode: '4900000000099',
          stockLevelsOnHand: 5,
          stockUnitsOnHand: 0,
          reason: 'unlinked jan_code',
        ),
      ]);

      await _pump(tester, repo);

      expect(find.text('商品に紐付いていないJAN'), findsOneWidget);
      expect(find.text('差分 +5'), findsOneWidget);
    });

    testWidgets('no discrepancies shows the healthy empty state', (tester) async {
      final repo = FakeInventoryRepository();

      await _pump(tester, repo);

      expect(find.text('ズレはありません'), findsOneWidget);
    });
  });
}
