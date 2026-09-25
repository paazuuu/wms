import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/bin_stock.dart';
import 'package:wms_mobile/features/warehouse_context/presentation/bin_stock_overview_screen.dart';

import '../../support/harness.dart';

void main() {
  group('BinStockOverviewScreen', () {
    testWidgets('shows each bin with its lines and total', (tester) async {
      final repo = FakeLocationRepository()
        ..binStock = const [
          BinStock(
            binId: 11,
            binCode: 'Z1-R-01-S3',
            binType: 'PICKING',
            lines: [
              BinStockLine(
                  janCode: '4900000000001', productName: 'ペン', onHand: 30),
              BinStockLine(
                  janCode: '4900000000002', productName: 'ノート', onHand: 5),
            ],
          ),
        ];

      await pumpApp(
        tester,
        const BinStockOverviewScreen(warehouseId: 1),
        overrides: [locationRepositoryProvider.overrideWithValue(repo)],
      );

      expect(find.text('Z1-R-01-S3'), findsOneWidget);
      expect(find.text('ペン'), findsOneWidget);
      expect(find.text('× 30'), findsOneWidget);
      expect(find.text('ノート'), findsOneWidget);
      expect(find.text('× 5'), findsOneWidget);
      // Total is the sum of the bin's lines, not just the first one.
      expect(find.text('計 35 点'), findsOneWidget);
    });

    testWidgets('an empty bin is tagged empty instead of given a count',
        (tester) async {
      final repo = FakeLocationRepository()
        ..binStock = const [
          BinStock(
            binId: 12,
            binCode: 'Z1-R-01-S4',
            binType: 'STORAGE',
            lines: [],
          ),
        ];

      await pumpApp(
        tester,
        const BinStockOverviewScreen(warehouseId: 1),
        overrides: [locationRepositoryProvider.overrideWithValue(repo)],
      );

      expect(find.text('Z1-R-01-S4'), findsOneWidget);
      expect(find.text('空'), findsOneWidget);
    });

    testWidgets('a warehouse with no bins shows the empty state',
        (tester) async {
      final repo = FakeLocationRepository();

      await pumpApp(
        tester,
        const BinStockOverviewScreen(warehouseId: 1),
        overrides: [locationRepositoryProvider.overrideWithValue(repo)],
      );

      expect(find.text('この倉庫にはロケーションがありません'), findsOneWidget);
    });
  });
}
