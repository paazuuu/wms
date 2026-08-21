import 'package:flutter/material.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/receiving/application/receiving_providers.dart';
import 'package:wms_mobile/features/receiving/data/receiving_repository.dart';
import 'package:wms_mobile/features/receiving/domain/purchase_order.dart';
import 'package:wms_mobile/features/receiving/domain/purchase_order_item.dart';
import 'package:wms_mobile/features/receiving/presentation/receiving_list_screen.dart';

/// In-memory fake so the list renders without a network. `list` filters by the
/// requested status, mirroring the real endpoint's status query parameter.
class _FakeReceivingRepository implements ReceivingRepository {
  _FakeReceivingRepository(this._all);

  final List<PurchaseOrder> _all;

  @override
  Future<ApiResult<List<PurchaseOrder>>> list({
    String? status,
    String? search,
  }) async {
    final filtered = status == null
        ? _all
        : _all.where((po) => po.status.name == status).toList();
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
}) =>
    PurchaseOrder(
      id: id,
      poNumber: number,
      status: status,
      supplierName: supplier,
      items: const [
        PurchaseOrderItem(
          id: 1,
          productId: 1,
          productName: 'Widget',
          sku: 'WID-1',
          quantityOrdered: 10,
          quantityReceived: 2,
          remainingQuantity: 8,
        ),
      ],
    );

Widget _wrap(ReceivingRepository repo) => ProviderScope(
      overrides: [
        receivingRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReceivingListScreen(),
      ),
    );

void main() {
  testWidgets('lists sent and partial purchase orders', (tester) async {
    final repo = _FakeReceivingRepository([
      _po(id: 2, number: 'PO-002', status: PurchaseOrderStatus.sent),
      _po(id: 1, number: 'PO-001', status: PurchaseOrderStatus.partial),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('PO-002'), findsOneWidget);
    expect(find.text('PO-001'), findsOneWidget);
    expect(find.text('Acme Supply'), findsNWidgets(2));
  });

  testWidgets('shows an empty state when nothing is receivable',
      (tester) async {
    await tester.pumpWidget(_wrap(_FakeReceivingRepository([])));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing to receive'), findsOneWidget);
  });
}
