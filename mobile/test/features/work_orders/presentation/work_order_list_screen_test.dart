import 'package:flutter/material.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/work_orders/application/work_order_providers.dart';
import 'package:wms_mobile/features/work_orders/data/work_order_repository.dart';
import 'package:wms_mobile/features/work_orders/domain/work_order.dart';
import 'package:wms_mobile/features/work_orders/presentation/work_order_list_screen.dart';

/// In-memory fake so the browse list renders without a network. `list` filters
/// by a case-insensitive WO-number / product substring.
class _FakeWorkOrderRepository implements WorkOrderRepository {
  _FakeWorkOrderRepository(this._all);

  final List<WorkOrder> _all;

  @override
  Future<ApiResult<List<WorkOrder>>> list({String? search, String? status}) async {
    final q = search?.trim().toLowerCase() ?? '';
    final filtered = q.isEmpty
        ? _all
        : _all
            .where((w) =>
                w.workOrderNumber.toLowerCase().contains(q) ||
                w.productName.toLowerCase().contains(q))
            .toList();
    return ApiSuccess(filtered);
  }

  @override
  Future<ApiResult<WorkOrder>> show(int id) async =>
      ApiSuccess(_all.firstWhere((w) => w.id == id));
}

WorkOrder _wo({
  required int id,
  required String number,
  required WorkOrderStatus status,
  String product = 'Gift Box',
  int quantity = 5,
}) =>
    WorkOrder(
      id: id,
      workOrderNumber: number,
      status: status,
      productName: product,
      quantity: quantity,
    );

Widget _wrap(WorkOrderRepository repo) => ProviderScope(
      overrides: [
        workOrderRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WorkOrderListScreen(),
      ),
    );

void main() {
  testWidgets('lists work orders with their status and quantity',
      (tester) async {
    final repo = _FakeWorkOrderRepository([
      _wo(id: 2, number: 'WO-002', status: WorkOrderStatus.completed),
      _wo(id: 1, number: 'WO-001', status: WorkOrderStatus.inProgress),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('WO-002'), findsOneWidget);
    expect(find.text('WO-001'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
  });

  testWidgets('filters results when a query is submitted', (tester) async {
    final repo = _FakeWorkOrderRepository([
      _wo(
          id: 1,
          number: 'WO-001',
          status: WorkOrderStatus.draft,
          product: 'Gift Box'),
      _wo(
          id: 2,
          number: 'WO-002',
          status: WorkOrderStatus.pending,
          product: 'Starter Kit'),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'starter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('WO-002'), findsOneWidget);
    expect(find.text('WO-001'), findsNothing);
  });

  testWidgets('shows an empty state when there are no work orders',
      (tester) async {
    await tester.pumpWidget(_wrap(_FakeWorkOrderRepository([])));
    await tester.pumpAndSettle();

    expect(find.textContaining('No work orders yet'), findsOneWidget);
  });
}
