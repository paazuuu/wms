import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/delivery/data/delivery_repository.dart';
import 'package:wms_mobile/features/delivery/data/stock_repository.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan.dart';
import 'package:wms_mobile/features/delivery/domain/receipt.dart';
import 'package:wms_mobile/features/delivery/domain/stock_item.dart';
import 'package:wms_mobile/features/delivery/domain/stock_movement.dart';
import 'package:wms_mobile/features/home/data/dashboard_repository.dart';
import 'package:wms_mobile/features/home/domain/dashboard_metrics.dart';
import 'package:wms_mobile/features/qc/data/inspection_repository.dart';
import 'package:wms_mobile/features/qc/domain/inspection.dart';
import 'package:wms_mobile/features/shipment/data/shipment_repository.dart';
import 'package:wms_mobile/features/warehouse_context/data/warehouse_repository.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';
import 'package:wms_mobile/features/shipment/domain/carton.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

/// Pumps [child] inside a localized MaterialApp and a ProviderScope with the
/// given [overrides], then settles. Locale is fixed to Japanese.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Like [pumpApp] but driven by a caller-owned [container], so a test can read
/// and write provider state around the pump (e.g. assert that tapping the
/// warehouse picker actually changed the active warehouse).
Future<void> pumpAppWith(
  WidgetTester tester,
  ProviderContainer container,
  Widget child,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Delivery repository stub. [plans] are filtered by status for list().
class FakeDeliveryRepository implements DeliveryRepository {
  FakeDeliveryRepository(this.plans);
  final List<DeliveryPlan> plans;

  @override
  Future<ApiResult<List<DeliveryPlan>>> list({String? status, String? search}) async =>
      ApiSuccess(status == null
          ? plans
          : plans.where((p) => p.status.wire == status).toList());

  @override
  Future<ApiResult<DeliveryPlan>> show(int id) async =>
      ApiSuccess(plans.firstWhere((p) => p.id == id));

  @override
  Future<ApiResult<DeliveryPlan>> reconcile(int id,
          {required List<ReconcileEntry> entries,
          String? noteReference,
          bool complete = true}) async =>
      ApiSuccess(plans.first);

  @override
  Future<ApiResult<ImportPreview>> previewPlan(
          {required MultipartFile file,
          String? deliveryNumber,
          String? supplier,
          String? supplierCode}) async =>
      const ApiSuccess(
          ImportPreview(source: 't', lineCount: 0, totalQuantity: 0, lines: []));

  @override
  Future<ApiResult<PlanImportResult>> commitPlan(PlanCommit commit) async =>
      const ApiSuccess(
          PlanImportResult(planId: 1, lineCount: 0, totalQuantity: 0));

  @override
  Future<ApiResult<List<Receipt>>> receipts(int planId) async =>
      const ApiSuccess([]);

  @override
  Future<ApiResult<DeliveryPlan>> cancelReceipt(int planId, int receiptId) async =>
      ApiSuccess(plans.first);
}

class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository(this.value);
  final DashboardMetrics value;

  /// The warehouse id the last call was scoped to (null = all warehouses).
  int? lastWarehouseId;

  @override
  Future<ApiResult<DashboardMetrics>> metrics(
      {int days = 14, int lowThreshold = 10, int? warehouseId}) async {
    lastWarehouseId = warehouseId;
    return ApiSuccess(value);
  }
}

/// Warehouse stub. [overviewValue] is returned as-is; [created] records what the
/// add-warehouse wizard submitted.
class FakeWarehouseRepository implements WarehouseRepository {
  FakeWarehouseRepository(this.overviewValue, {this.binsByWarehouse = const {}});

  final WarehouseOverview overviewValue;
  final Map<int, List<Bin>> binsByWarehouse;
  final List<NewWarehouse> created = [];

  @override
  Future<ApiResult<WarehouseOverview>> overview() async =>
      ApiSuccess(overviewValue);

  @override
  Future<ApiResult<Warehouse>> create(NewWarehouse warehouse) async {
    created.add(warehouse);
    return ApiSuccess(Warehouse(
      id: 999,
      code: warehouse.code,
      name: warehouse.name,
      status: warehouse.isActive ? 'active' : 'inactive',
      timezone: warehouse.timezone,
    ));
  }

  @override
  Future<ApiResult<Warehouse>> update(
    int id, {
    String? name,
    String? address,
    String? phone,
    String? timezone,
    bool? isActive,
  }) async =>
      ApiSuccess(overviewValue.byId(id) ??
          Warehouse(id: id, code: 'X', name: name ?? 'X'));

  @override
  Future<ApiResult<List<Bin>>> bins(int warehouseId) async =>
      ApiSuccess(binsByWarehouse[warehouseId] ?? const []);
}

/// Inspection stub. Mirrors the server's derivation of an item result from the
/// pass/fail split and its refusal to close while items are unchecked, so a
/// screen test exercises the same rules the backend enforces.
class FakeInspectionRepository implements InspectionRepository {
  FakeInspectionRepository(this.inspection);
  Inspection inspection;

  /// Set when complete() was rejected because lines were still unchecked.
  bool refusedIncomplete = false;

  @override
  Future<ApiResult<List<Inspection>>> list(
          {String? status, int? warehouseId}) async =>
      ApiSuccess(status == null || inspection.status.wire == status
          ? [inspection]
          : const []);

  @override
  Future<ApiResult<Inspection>> show(int id) async => ApiSuccess(inspection);

  @override
  Future<ApiResult<Inspection>> start(int reconciliationId) async =>
      ApiSuccess(inspection);

  @override
  Future<ApiResult<Inspection>> saveItem(
      int inspectionId, int itemId, InspectionFinding finding) async {
    final result = finding.hold
        ? QcResult.hold
        : finding.passedQuantity == 0 && finding.failedQuantity == 0
            ? QcResult.pending
            : finding.failedQuantity == 0
                ? QcResult.pass
                : finding.passedQuantity == 0
                    ? QcResult.fail
                    : QcResult.partial;
    inspection = Inspection(
      id: inspection.id,
      status: inspection.status,
      deliveryNumber: inspection.deliveryNumber,
      supplierName: inspection.supplierName,
      items: [
        for (final it in inspection.items)
          if (it.id == itemId)
            InspectionItem(
              id: it.id,
              janCode: it.janCode,
              productName: it.productName,
              expectedQuantity: it.expectedQuantity,
              actualQuantity:
                  finding.passedQuantity + finding.failedQuantity,
              passedQuantity: finding.passedQuantity,
              failedQuantity: finding.failedQuantity,
              discrepancy: finding.passedQuantity +
                  finding.failedQuantity -
                  it.expectedQuantity,
              result: result,
            )
          else
            it,
      ],
    );
    return ApiSuccess(inspection);
  }

  @override
  Future<ApiResult<Inspection>> complete(int inspectionId,
      {String? note}) async {
    if (inspection.uncheckedCount > 0) {
      refusedIncomplete = true;
      return const ApiFailure(
          message: 'inspection still has unchecked item(s)', statusCode: 422);
    }
    final results = inspection.items.map((i) => i.result).toSet();
    final status = results.contains(QcResult.hold)
        ? QcResult.hold
        : results.length == 1 && results.first == QcResult.pass
            ? QcResult.pass
            : results.length == 1 && results.first == QcResult.fail
                ? QcResult.fail
                : QcResult.partial;
    inspection = Inspection(
      id: inspection.id,
      status: status,
      deliveryNumber: inspection.deliveryNumber,
      supplierName: inspection.supplierName,
      items: inspection.items,
    );
    return ApiSuccess(inspection);
  }
}

class FakeStockRepository implements StockRepository {
  FakeStockRepository(this.items, {this.movements = const []});
  final List<StockItem> items;
  final List<StockMovement> movements;

  /// The warehouse the last list() call was scoped to (null = all warehouses).
  int? lastWarehouseId;

  @override
  Future<ApiResult<List<StockItem>>> list({int? warehouseId}) async {
    lastWarehouseId = warehouseId;
    return ApiSuccess(items);
  }

  @override
  Future<ApiResult<List<StockMovement>>> ledger(
    String janCode, {
    int? warehouseId,
    int limit = 100,
  }) async =>
      ApiSuccess(movements.where((m) => m.janCode == janCode).toList());
}

class FakeShipmentRepository implements ShipmentRepository {
  FakeShipmentRepository(this.shipments);
  final List<Shipment> shipments;

  @override
  Future<ApiResult<List<Shipment>>> list({String? status, String? search}) async =>
      ApiSuccess(status == null
          ? shipments
          : shipments.where((s) => s.status.wire == status).toList());

  @override
  Future<ApiResult<Shipment>> show(int id) async =>
      ApiSuccess(shipments.firstWhere((s) => s.id == id));

  @override
  Future<ApiResult<Shipment>> ship(int id) async => show(id);

  @override
  Future<ApiResult<Shipment>> cancel(int id) async => show(id);

  @override
  Future<ApiResult<Shipment>> createCarton(int id, {String? label}) async =>
      show(id);

  @override
  Future<ApiResult<Shipment>> deleteCarton(int id, int cartonId) async =>
      show(id);

  @override
  Future<ApiResult<Shipment>> updateCarton(int id, int cartonId,
          {String? label, required List<CartonItem> items}) async =>
      show(id);
}
