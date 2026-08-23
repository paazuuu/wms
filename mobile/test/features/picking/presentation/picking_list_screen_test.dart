import 'package:flutter/material.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/sales_orders/data/sales_order_repository.dart';
import 'package:wms_mobile/features/sales_orders/application/sales_order_providers.dart';
import 'package:wms_mobile/features/sales_orders/domain/sales_order.dart';
import 'package:wms_mobile/features/picking/presentation/picking_list_screen.dart';

/// In-memory fake returning a fixed set of orders regardless of the query.
class _FakeSalesOrderRepository implements SalesOrderRepository {
  _FakeSalesOrderRepository(this._all);

  final List<SalesOrder> _all;

  @override
  Future<ApiResult<List<SalesOrder>>> list({
    String? search,
    String? status,
  }) async =>
      ApiSuccess(_all);

  @override
  Future<ApiResult<SalesOrder>> show(int id) async =>
      ApiSuccess(_all.firstWhere((o) => o.id == id));
}

Widget _wrap(SalesOrderRepository repo) => ProviderScope(
      overrides: [
        salesOrderRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PickingListScreen(),
      ),
    );

void main() {
  testWidgets('lists only open orders as pick lists', (tester) async {
    final repo = _FakeSalesOrderRepository(const [
      SalesOrder(
        id: 1,
        orderNumber: 'SO-1001',
        status: SalesOrderStatus.pending,
        customerName: 'Acme',
        itemsCount: 2,
      ),
      SalesOrder(
        id: 2,
        orderNumber: 'SO-1002',
        status: SalesOrderStatus.processing,
        customerName: 'Globex',
        itemsCount: 1,
      ),
      // Fulfilled / cancelled orders must be filtered out.
      SalesOrder(
        id: 3,
        orderNumber: 'SO-1003',
        status: SalesOrderStatus.delivered,
        customerName: 'Initech',
      ),
      SalesOrder(
        id: 4,
        orderNumber: 'SO-1004',
        status: SalesOrderStatus.cancelled,
        customerName: 'Umbrella',
      ),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('SO-1001'), findsOneWidget);
    expect(find.text('SO-1002'), findsOneWidget);
    expect(find.text('SO-1003'), findsNothing);
    expect(find.text('SO-1004'), findsNothing);
  });

  testWidgets('shows an empty state when nothing is open', (tester) async {
    await tester.pumpWidget(_wrap(_FakeSalesOrderRepository(const [])));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing to pick'), findsOneWidget);
  });
}
