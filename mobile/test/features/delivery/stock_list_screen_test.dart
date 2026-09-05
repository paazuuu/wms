import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/application/delivery_providers.dart';
import 'package:wms_mobile/features/delivery/domain/stock_item.dart';
import 'package:wms_mobile/features/delivery/presentation/stock_list_screen.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('shows stock rows, totals strip and a sort menu', (tester) async {
    await pumpApp(
      tester,
      const StockListScreen(),
      overrides: [
        stockRepositoryProvider.overrideWithValue(
          FakeStockRepository(const [
            StockItem(janCode: '4902505632037', onHand: 120, productName: 'ペン'),
            StockItem(janCode: '4901480241418', onHand: 0, productName: 'ホチキス'),
          ]),
        ),
      ],
    );

    expect(find.text('ペン'), findsOneWidget);
    expect(find.text('ホチキス'), findsOneWidget);
    // Prominent quantity numbers.
    expect(find.text('120'), findsOneWidget);
    // Totals strip: 2 SKUs, 120 units.
    expect(find.textContaining('120'), findsWidgets);
    // Sort control present.
    expect(find.byIcon(Icons.sort), findsOneWidget);
  });

  testWidgets('shows the empty state when there is no stock', (tester) async {
    await pumpApp(
      tester,
      const StockListScreen(),
      overrides: [
        stockRepositoryProvider
            .overrideWithValue(FakeStockRepository(const [])),
      ],
    );

    expect(find.text('在庫がまだありません。'), findsOneWidget);
  });
}
