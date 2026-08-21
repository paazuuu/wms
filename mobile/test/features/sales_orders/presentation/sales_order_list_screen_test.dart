import 'package:flutter/material.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/sales_orders/application/sales_order_providers.dart';
import 'package:wms_mobile/features/sales_orders/data/sales_order_repository.dart';
import 'package:wms_mobile/features/sales_orders/domain/sales_order.dart';
import 'package:wms_mobile/features/sales_orders/presentation/sales_order_list_screen.dart';

/// In-memory fake so the list renders without a network. `list` filters by a
/// case-insensitive order-number / customer substring.
class _FakeSalesOrderRepository implements SalesOrderRepository {
  _FakeSalesOrderRepository(this._all);

  final List<SalesOrder> _all;

  @override
  Future<ApiResult<List<SalesOrder>>> list({
    String? search,
    String? status,
  }) async {
    final q = search?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return ApiSuccess(_all);
    final filtered = _all
        .where((o) =>
            o.orderNumber.toLowerCase().contains(q) ||
            (o.customerName?.toLowerCase().contains(q) ?? false))
        .toList();
    return ApiSuccess(filtered);
  }

  @override
  Future<ApiResult<SalesOrder>> show(int id) async =>
      ApiSuccess(_all.firstWhere((o) => o.id == id));
}

SalesOrder _order({
  required int id,
  required String number,
  required SalesOrderStatus status,
  String? customer,
  String? total,
  String currency = 'USD',
  int? itemsCount,
}) =>
    SalesOrder(
      id: id,
      orderNumber: number,
      status: status,
      customerName: customer,
      total: total,
      currency: currency,
      itemsCount: itemsCount,
    );

Widget _wrap(SalesOrderRepository repo) => ProviderScope(
      overrides: [
        salesOrderRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SalesOrderListScreen(),
      ),
    );

void main() {
  testWidgets('lists orders with status, total and line count',
      (tester) async {
    final repo = _FakeSalesOrderRepository([
      _order(
        id: 1,
        number: 'SO-0001',
        status: SalesOrderStatus.processing,
        customer: 'Jane Doe',
        total: '47.00',
        itemsCount: 2,
      ),
      _order(
        id: 2,
        number: 'SO-0002',
        status: SalesOrderStatus.delivered,
        customer: 'John Roe',
        total: '10.00',
        itemsCount: 1,
      ),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('SO-0001'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('Processing'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('USD 47.00'), findsOneWidget);
    expect(find.text('2 lines'), findsOneWidget);
    expect(find.text('1 line'), findsOneWidget);
  });

  testWidgets('filters results when a query is submitted', (tester) async {
    final repo = _FakeSalesOrderRepository([
      _order(
          id: 1,
          number: 'SO-0001',
          status: SalesOrderStatus.pending,
          customer: 'Jane Doe'),
      _order(
          id: 2,
          number: 'SO-0002',
          status: SalesOrderStatus.pending,
          customer: 'John Roe'),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'roe');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('SO-0002'), findsOneWidget);
    expect(find.text('SO-0001'), findsNothing);
  });

  testWidgets('shows an empty state when there are no orders', (tester) async {
    await tester.pumpWidget(_wrap(_FakeSalesOrderRepository([])));
    await tester.pumpAndSettle();

    expect(find.textContaining('No sales orders yet'), findsOneWidget);
  });
}
