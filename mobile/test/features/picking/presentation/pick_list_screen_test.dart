import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/sales_orders/data/sales_order_repository.dart';
import 'package:wms_mobile/features/sales_orders/application/sales_order_providers.dart';
import 'package:wms_mobile/features/sales_orders/domain/sales_order.dart';
import 'package:wms_mobile/features/sales_orders/domain/sales_order_item.dart';
import 'package:wms_mobile/features/picking/presentation/pick_list_screen.dart';

/// Serves one order (with lines) for the detail lookup.
class _FakeSalesOrderRepository implements SalesOrderRepository {
  _FakeSalesOrderRepository(this._order);

  final SalesOrder _order;

  @override
  Future<ApiResult<List<SalesOrder>>> list({
    String? search,
    String? status,
  }) async =>
      ApiSuccess([_order]);

  @override
  Future<ApiResult<SalesOrder>> show(int id) async => ApiSuccess(_order);
}

const _order = SalesOrder(
  id: 7,
  orderNumber: 'SO-2007',
  status: SalesOrderStatus.processing,
  customerName: 'Acme',
  items: [
    SalesOrderItem(
        id: 11, productId: 1, productName: 'Widget', sku: 'W-1', quantity: 3),
    SalesOrderItem(
        id: 12, productId: 2, productName: 'Gadget', sku: 'G-2', quantity: 5),
  ],
);

Widget _wrap() => ProviderScope(
      overrides: [
        salesOrderRepositoryProvider
            .overrideWithValue(_FakeSalesOrderRepository(_order)),
      ],
      child: const MaterialApp(home: PickListScreen(orderId: 7)),
    );

void main() {
  testWidgets('renders line items with initial progress', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('SO-2007'), findsOneWidget);
    expect(find.text('Widget'), findsOneWidget);
    expect(find.text('Gadget'), findsOneWidget);
    expect(find.text('0 / 2 picked'), findsOneWidget);
  });

  testWidgets('checking a line advances the picked count', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('1 / 2 picked'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    expect(find.text('2 / 2 picked'), findsOneWidget);
  });
}
