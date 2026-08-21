import 'package:flutter/material.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/receiving/application/receiving_providers.dart';
import 'package:wms_mobile/features/receiving/data/receiving_repository.dart';
import 'package:wms_mobile/features/receiving/domain/purchase_order.dart';
import 'package:wms_mobile/features/purchase_orders/presentation/purchase_order_list_screen.dart';

/// In-memory fake so the browse list renders without a network. `list` filters
/// by a case-insensitive PO-number / supplier substring and ignores status
/// (the browse view shows every status).
class _FakePurchaseOrderRepository implements ReceivingRepository {
  _FakePurchaseOrderRepository(this._all);

  final List<PurchaseOrder> _all;

  @override
  Future<ApiResult<List<PurchaseOrder>>> list({
    String? status,
    String? search,
  }) async {
    final q = search?.trim().toLowerCase() ?? '';
    final filtered = q.isEmpty
        ? _all
        : _all
            .where((po) =>
                po.poNumber.toLowerCase().contains(q) ||
                (po.supplierName?.toLowerCase().contains(q) ?? false))
            .toList();
    return ApiSuccess(filtered);
  }

  @override
  Future<ApiResult<PurchaseOrder>> show(int id) async =>
      ApiSuccess(_all.firstWhere((po) => po.id == id));

  @override
  Future<ApiResult<PurchaseOrder>> receive(
          int id, List<ReceiveLine> lines) async =>
      ApiSuccess(_all.firstWhere((po) => po.id == id));
}

PurchaseOrder _po({
  required int id,
  required String number,
  required PurchaseOrderStatus status,
  String supplier = 'Acme Supply',
  int itemsCount = 1,
}) =>
    PurchaseOrder(
      id: id,
      poNumber: number,
      status: status,
      supplierName: supplier,
      itemsCount: itemsCount,
    );

Widget _wrap(ReceivingRepository repo) => ProviderScope(
      overrides: [
        receivingRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PurchaseOrderListScreen(),
      ),
    );

void main() {
  testWidgets('lists purchase orders of every status', (tester) async {
    final repo = _FakePurchaseOrderRepository([
      _po(id: 3, number: 'PO-003', status: PurchaseOrderStatus.received),
      _po(id: 2, number: 'PO-002', status: PurchaseOrderStatus.draft),
      _po(id: 1, number: 'PO-001', status: PurchaseOrderStatus.cancelled),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('PO-003'), findsOneWidget);
    expect(find.text('PO-002'), findsOneWidget);
    expect(find.text('PO-001'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('filters results when a query is submitted', (tester) async {
    final repo = _FakePurchaseOrderRepository([
      _po(
          id: 1,
          number: 'PO-001',
          status: PurchaseOrderStatus.sent,
          supplier: 'Acme Supply'),
      _po(
          id: 2,
          number: 'PO-002',
          status: PurchaseOrderStatus.draft,
          supplier: 'Globex'),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'globex');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('PO-002'), findsOneWidget);
    expect(find.text('PO-001'), findsNothing);
  });

  testWidgets('shows an empty state when there are no purchase orders',
      (tester) async {
    await tester.pumpWidget(_wrap(_FakePurchaseOrderRepository([])));
    await tester.pumpAndSettle();

    expect(find.textContaining('No purchase orders yet'), findsOneWidget);
  });
}
