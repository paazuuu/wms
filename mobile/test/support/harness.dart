import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/providers.dart';
import 'package:wms_mobile/core/storage/supabase_session_storage.dart';
import 'package:wms_mobile/features/admin/data/admin_repository.dart';
import 'package:wms_mobile/features/admin/domain/app_user_summary.dart';
import 'package:wms_mobile/features/ai_review/data/ai_review_repository.dart';
import 'package:wms_mobile/features/ai_review/domain/ai_analysis_entry.dart';
import 'package:wms_mobile/features/connectors/data/connector_repository.dart';
import 'package:wms_mobile/features/connectors/domain/connector.dart';
import 'package:wms_mobile/features/delivery/data/delivery_repository.dart';
import 'package:wms_mobile/features/exceptions/data/exception_repository.dart';
import 'package:wms_mobile/features/exceptions/domain/warehouse_exception.dart';
import 'package:wms_mobile/features/delivery/data/stock_repository.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan.dart';
import 'package:wms_mobile/features/delivery/domain/receipt.dart';
import 'package:wms_mobile/features/delivery/domain/receipt_detail.dart';
import 'package:wms_mobile/features/delivery/domain/stock_item.dart';
import 'package:wms_mobile/features/delivery/domain/stock_movement.dart';
import 'package:wms_mobile/features/delivery/domain/stock_position.dart';
import 'package:wms_mobile/features/home/data/dashboard_repository.dart';
import 'package:wms_mobile/features/home/domain/dashboard_metrics.dart';
import 'package:wms_mobile/features/qc/application/attachment_providers.dart';
import 'package:wms_mobile/features/qc/data/attachment_repository.dart';
import 'package:wms_mobile/features/qc/data/inspection_repository.dart';
import 'package:wms_mobile/features/qc/domain/attachment.dart';
import 'package:wms_mobile/features/qc/domain/held_stock.dart';
import 'package:wms_mobile/features/qc/domain/inspection.dart';
import 'package:wms_mobile/features/picking_ops/data/picking_repository.dart';
import 'package:wms_mobile/features/picking_ops/domain/pick_list.dart';
import 'package:wms_mobile/features/partners/application/trading_partner_providers.dart';
import 'package:wms_mobile/features/partners/data/trading_partner_repository.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/data/product_repository.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/inventory/data/inventory_repository.dart';
import 'package:wms_mobile/features/inventory/domain/reservation.dart';
import 'package:wms_mobile/features/product/domain/product_lot.dart';
import 'package:wms_mobile/features/product/domain/warehouse_product.dart';
import 'package:wms_mobile/features/purchasing/application/purchase_order_providers.dart';
import 'package:wms_mobile/features/purchasing/data/purchase_order_repository.dart';
import 'package:wms_mobile/features/purchasing/domain/purchase_order.dart';
import 'package:wms_mobile/features/putaway/application/putaway_providers.dart';
import 'package:wms_mobile/features/putaway/data/putaway_repository.dart';
import 'package:wms_mobile/features/putaway/domain/putaway_task.dart';
import 'package:wms_mobile/features/reports/application/report_providers.dart';
import 'package:wms_mobile/features/reports/data/report_repository.dart';
import 'package:wms_mobile/features/reports/domain/report.dart';
import 'package:wms_mobile/features/sales/application/sales_order_providers.dart';
import 'package:wms_mobile/features/sales/data/sales_order_repository.dart';
import 'package:wms_mobile/features/sales/domain/sales_order.dart';
import 'package:wms_mobile/features/work_orders/application/work_order_providers.dart';
import 'package:wms_mobile/features/work_orders/data/work_order_repository.dart';
import 'package:wms_mobile/features/work_orders/domain/work_order.dart';
import 'package:wms_mobile/features/audit/data/audit_repository.dart';
import 'package:wms_mobile/features/audit/domain/audit_entry.dart';
import 'package:wms_mobile/features/search/data/search_repository.dart';
import 'package:wms_mobile/features/search/domain/search_result.dart';
import 'package:wms_mobile/features/shipment/data/shipment_repository.dart';
import 'package:wms_mobile/features/transfers/data/transfer_repository.dart';
import 'package:wms_mobile/features/transfers/domain/transfer_order.dart';
import 'package:wms_mobile/features/stock_ops/data/stock_ops_repository.dart';
import 'package:wms_mobile/features/stock_ops/domain/stock_ops.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/data/warehouse_repository.dart';
import 'package:wms_mobile/features/warehouse_context/data/location_repository.dart';
import 'package:wms_mobile/features/warehouse_context/domain/bin_stock.dart';
import 'package:wms_mobile/features/warehouse_context/domain/location.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';
import 'package:wms_mobile/core/api/supabase_auth_interceptor.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/data/auth_repository.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/shipment/domain/carton.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';
import 'package:wms_mobile/features/shipment/domain/shipment_parcel.dart';
import 'package:wms_mobile/features/wave/application/pick_wave_providers.dart';
import 'package:wms_mobile/features/wave/data/pick_wave_repository.dart';
import 'package:wms_mobile/features/wave/domain/pick_wave.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

/// In-memory stand-in for the platform keychain/keystore. The real plugin has
/// no test-harness implementation and its platform channel simply never
/// replies outside a running app, which would otherwise hang every screen
/// test that touches a Supabase-backed Dio client (all of them go through
/// [SupabaseAuthInterceptor], which reads the stored session on every
/// request).
class _FakeSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// Default overrides applied by [pumpApp]/[pumpAppWith] so no test needs to
/// know about the Supabase auth session store to avoid the hang above, or
/// stub the warehouse overview just to keep an unrelated screen (e.g. admin
/// user management, which resolves warehouse names for its scope chips)
/// from reaching a real Dio client. A test that cares about warehouse data
/// overrides `warehouseRepositoryProvider` itself, which wins over this.
List<Override> _defaultOverrides() => [
      supabaseSessionStorageProvider
          .overrideWithValue(SupabaseSessionStorage(_FakeSecureKeyValueStore())),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(
        const WarehouseOverview(warehouses: [], totals: WarehouseTotals()),
      )),
      attachmentRepositoryProvider.overrideWithValue(FakeAttachmentRepository()),
      productRepositoryProvider.overrideWithValue(FakeProductRepository()),
      purchaseOrderRepositoryProvider
          .overrideWithValue(FakePurchaseOrderRepository()),
      salesOrderRepositoryProvider.overrideWithValue(FakeSalesOrderRepository()),
      tradingPartnerRepositoryProvider
          .overrideWithValue(FakeTradingPartnerRepository()),
      workOrderRepositoryProvider.overrideWithValue(FakeWorkOrderRepository()),
      reportRepositoryProvider.overrideWithValue(FakeReportRepository()),
      putawayRepositoryProvider.overrideWithValue(FakePutawayRepository()),
      pickWaveRepositoryProvider.overrideWithValue(FakePickWaveRepository()),
    ];

/// Pumps [child] inside a localized MaterialApp and a ProviderScope with the
/// given [overrides], then settles. Locale is fixed to Japanese.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [..._defaultOverrides(), ...overrides],
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
///
/// The caller owns [container], so it must apply [_defaultOverrides] itself
/// when constructing it (see e.g. how other tests build their container).
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
  FakeDeliveryRepository(this.plans, {ImportPreview? preview})
      : preview = preview ??
            const ImportPreview(
                source: 't', lineCount: 0, totalQuantity: 0, lines: []);
  final List<DeliveryPlan> plans;

  /// What previewPlan() returns — override the constructor default to test
  /// the review step with known lines.
  ImportPreview preview;

  /// The commit the last commitPlan() call actually sent, lines included —
  /// so a test can assert an edit/split/merge/delete reached the payload.
  PlanCommit? lastCommit;

  /// The warehouse the last list() call was scoped to.
  int? lastWarehouseId;

  /// When set, reconcile()/commitPlan()/cancelReceipt() fail with this
  /// message instead of succeeding — e.g. to simulate a permission-denied
  /// RPC response (receiving.confirm / pack.complete).
  String? failWith;

  /// §12's three levels for one receipt (0067). Set [detail] to serve one.
  ReceiptDetail? detail;
  int? lastDetailId;
  List<LotProvenance> provenance = const [];
  ({int productId, String? lotCode})? lastProvenanceQuery;

  @override
  Future<ApiResult<ReceiptDetail>> receiptDetail(int reconciliationId) async {
    lastDetailId = reconciliationId;
    final d = detail;
    if (d == null) {
      return const ApiFailure(message: 'receipt not found', statusCode: 404);
    }
    return ApiSuccess(d);
  }

  @override
  Future<ApiResult<List<LotProvenance>>> lotProvenance(
    int productId, {
    String? lotCode,
  }) async {
    lastProvenanceQuery = (productId: productId, lotCode: lotCode);
    return ApiSuccess(lotCode == null
        ? provenance
        : provenance.where((p) => p.lotCode == lotCode).toList());
  }

  @override
  Future<ApiResult<List<DeliveryPlan>>> list(
      {String? status, String? search, int? warehouseId}) async {
    lastWarehouseId = warehouseId;
    return ApiSuccess(status == null
        ? plans
        : plans.where((p) => p.status.wire == status).toList());
  }

  @override
  Future<ApiResult<DeliveryPlan>> show(int id) async =>
      ApiSuccess(plans.firstWhere((p) => p.id == id));

  @override
  Future<ApiResult<DeliveryPlan>> reconcile(int id,
      {required List<ReconcileEntry> entries,
      String? noteReference,
      bool complete = true}) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    return ApiSuccess(plans.first);
  }

  @override
  Future<ApiResult<ImportPreview>> previewPlan(
          {required MultipartFile file,
          String? deliveryNumber,
          String? supplier,
          String? supplierCode}) async =>
      ApiSuccess(preview);

  @override
  Future<ApiResult<PlanImportResult>> commitPlan(PlanCommit commit) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    lastCommit = commit;
    return ApiSuccess(PlanImportResult(
        planId: 1,
        lineCount: commit.lines.length,
        totalQuantity: 0));
  }

  @override
  Future<ApiResult<List<Receipt>>> receipts(int planId) async =>
      const ApiSuccess([]);

  @override
  Future<ApiResult<DeliveryPlan>> cancelReceipt(int planId, int receiptId) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    return ApiSuccess(plans.first);
  }
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

  /// When set, create() fails with this message instead of succeeding — e.g.
  /// to simulate a permission-denied RPC response (warehouse.manage).
  String? failWith;

  @override
  Future<ApiResult<WarehouseOverview>> overview() async =>
      ApiSuccess(overviewValue);

  @override
  Future<ApiResult<Warehouse>> create(NewWarehouse warehouse) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    created.add(warehouse);
    return ApiSuccess(Warehouse(
      id: 999,
      code: warehouse.code,
      name: warehouse.name,
      status: warehouse.isActive ? 'active' : 'inactive',
      usesLocations: warehouse.usesLocations,
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
    bool? usesLocations,
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
  /// The inspection is optional because this fake also serves the held-stock
  /// screen, which has no inspection in play at all.
  FakeInspectionRepository([Inspection? inspection])
      : inspection =
            inspection ?? const Inspection(id: 0, status: QcResult.pending);
  Inspection inspection;

  /// Set when complete() was rejected because lines were still unchecked.
  bool refusedIncomplete = false;

  /// When set, saveItem()/complete() fail with this message instead of
  /// succeeding — e.g. to simulate a permission-denied RPC response
  /// (inspection.confirm).
  String? failWith;

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

  /// Overrides the computed effect, for a test that wants to show a specific
  /// one (a release with nothing held, say).
  InspectionStockEffect? stockEffect;
  String? lastFailStatus;
  List<HeldStock> held = const [];
  int? lastHeldWarehouseId;

  @override
  Future<ApiResult<Inspection>> complete(int inspectionId,
      {String? note, String? failStatus}) async {
    lastFailStatus = failStatus;
    if (failWith != null) return ApiFailure(message: failWith!);
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
    // Mirrors 0068: passed goods are released to OK, failed goods go to
    // `failStatus` (DAMAGED unless the caller says otherwise). The fake computes
    // it from the items rather than hard-coding a number, so a test that changes
    // the findings gets the matching effect.
    final passed = inspection.items.fold(0, (s, i) => s + i.passedQuantity);
    final failed = inspection.items.fold(0, (s, i) => s + i.failedQuantity);
    inspection = Inspection(
      id: inspection.id,
      status: status,
      deliveryNumber: inspection.deliveryNumber,
      supplierName: inspection.supplierName,
      items: inspection.items,
      stockEffect: stockEffect ??
          InspectionStockEffect(
            releasedToOk: passed,
            failedQuantity: failed,
            failedTo: failed > 0 ? (failStatus ?? 'DAMAGED') : null,
          ),
    );
    return ApiSuccess(inspection);
  }

  @override
  Future<ApiResult<List<HeldStock>>> heldStock({int? warehouseId}) async {
    lastHeldWarehouseId = warehouseId;
    return ApiSuccess(held);
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

  /// Per-product positions a test wants [position] to answer with. A product
  /// with no entry answers with zeroes, which is what the real RPC does for a
  /// product that has no stock in this warehouse.
  Map<int, StockPosition> positions = const {};

  /// The last (productId, warehouseId) [position] was asked for.
  ({int productId, int? warehouseId})? lastPositionQuery;

  @override
  Future<ApiResult<StockPosition>> position(
    int productId, {
    int? warehouseId,
  }) async {
    lastPositionQuery = (productId: productId, warehouseId: warehouseId);
    return ApiSuccess(positions[productId] ??
        StockPosition(productId: productId, warehouseId: warehouseId));
  }
}

class FakeShipmentRepository implements ShipmentRepository {
  FakeShipmentRepository(this.shipments, {this.packingFixture});
  final List<Shipment> shipments;

  /// The packing state packing()/packCartonItem()/removeCartonItem()/
  /// setCartonLabel() read and mutate. A test sets it up front; the fake
  /// keeps it in sync the way the real RPCs would, so a screen test can add
  /// a parcel and see the result on the next read, the same way
  /// FakePickingRepository does for pick_items.
  ShipmentPacking? packingFixture;
  int _nextCartonItemId = 1000;

  /// The warehouse the last list() call was scoped to.
  int? lastWarehouseId;

  /// When set, ship() fails with this message instead of succeeding — e.g.
  /// to simulate a permission-denied RPC response (ship.complete).
  String? failWith;

  @override
  Future<ApiResult<List<Shipment>>> list(
      {String? status, String? search, int? warehouseId}) async {
    lastWarehouseId = warehouseId;
    return ApiSuccess(status == null
        ? shipments
        : shipments.where((s) => s.status.wire == status).toList());
  }

  @override
  Future<ApiResult<Shipment>> show(int id) async =>
      ApiSuccess(shipments.firstWhere((s) => s.id == id));

  /// The last autopack request, as (unitsPerCarton, resulting carton count).
  int? lastUnitsPerCarton;

  /// The last logistics values written.
  (double?, String?, String?)? lastLogistics;

  @override
  Future<ApiResult<AutopackResult>> autopack(int id,
      {required int unitsPerCarton}) async {
    lastUnitsPerCarton = unitsPerCarton;
    final shipment = shipments.firstWhere((s) => s.id == id);
    final total = shipment.totalUnits;
    // Same arithmetic the server does, so a screen test sees a real box count.
    final boxes = unitsPerCarton <= 0 ? 0 : (total + unitsPerCarton - 1) ~/ unitsPerCarton;
    return ApiSuccess(AutopackResult(
      cartonCount: boxes,
      unitsPerCarton: unitsPerCarton,
      totalUnits: total,
    ));
  }

  @override
  Future<ApiResult<bool>> setLogistics(
    int id, {
    double? weightKg,
    String? carrier,
    String? trackingNumber,
  }) async {
    lastLogistics = (weightKg, carrier, trackingNumber);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<Shipment>> ship(int id) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    return show(id);
  }

  @override
  Future<ApiResult<Shipment>> cancel(int id) async => show(id);

  @override
  Future<ApiResult<Shipment>> createCarton(int id, {String? label}) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    return show(id);
  }

  @override
  Future<ApiResult<Shipment>> deleteCarton(int id, int cartonId) async =>
      show(id);

  int? lastRenamedCartonId;
  String? lastCartonLabel;

  @override
  Future<ApiResult<bool>> setCartonLabel(int cartonId, String? label) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    lastRenamedCartonId = cartonId;
    lastCartonLabel = label;
    final p = packingFixture;
    if (p != null) {
      packingFixture = ShipmentPacking(
        shipmentPlanId: p.shipmentPlanId,
        lines: p.lines,
        cartons: [
          for (final c in p.cartons)
            if (c.id == cartonId) _withLabel(c, label) else c,
        ],
      );
    }
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<ShipmentPacking>> packing(int planId) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    final p = packingFixture;
    if (p == null) {
      throw StateError('FakeShipmentRepository.packingFixture was not set');
    }
    return ApiSuccess(p);
  }

  @override
  Future<ApiResult<bool>> packCartonItem(
    int cartonId, {
    required int quantity,
    required String janCode,
    String? lotCode,
    String? serialNumber,
    int? stockUnitId,
    String? note,
  }) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    final p = packingFixture;
    if (p == null) return const ApiSuccess(true);
    final productName =
        p.lines.firstWhere((l) => l.janCode == janCode).productName;
    final item = CartonItem(
      id: _nextCartonItemId++,
      janCode: janCode,
      productName: productName,
      quantity: quantity,
      lotCode: lotCode,
      serialNumber: serialNumber,
      stockUnitId: stockUnitId,
      note: note,
    );
    packingFixture = ShipmentPacking(
      shipmentPlanId: p.shipmentPlanId,
      lines: [
        for (final l in p.lines)
          if (l.janCode == janCode)
            PackableLine(
              productId: l.productId,
              janCode: l.janCode,
              productName: l.productName,
              packable: l.packable,
              packed: l.packed + quantity,
              unpacked: l.unpacked - quantity,
            )
          else
            l,
      ],
      cartons: [
        for (final c in p.cartons)
          if (c.id == cartonId) _withItems(c, [...c.items, item]) else c,
      ],
    );
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> removeCartonItem(int itemId) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    final p = packingFixture;
    if (p == null) return const ApiSuccess(true);
    CartonItem? removed;
    for (final c in p.cartons) {
      for (final it in c.items) {
        if (it.id == itemId) removed = it;
      }
    }
    if (removed == null) return const ApiSuccess(true);
    final r = removed;
    packingFixture = ShipmentPacking(
      shipmentPlanId: p.shipmentPlanId,
      lines: [
        for (final l in p.lines)
          if (l.janCode == r.janCode)
            PackableLine(
              productId: l.productId,
              janCode: l.janCode,
              productName: l.productName,
              packable: l.packable,
              packed: l.packed - r.quantity,
              unpacked: l.unpacked + r.quantity,
            )
          else
            l,
      ],
      cartons: [
        for (final c in p.cartons)
          _withItems(c, c.items.where((it) => it.id != itemId).toList()),
      ],
    );
    return const ApiSuccess(true);
  }

  Carton _withItems(Carton c, List<CartonItem> items) => Carton(
        id: c.id,
        cartonNo: c.cartonNo,
        label: c.label,
        items: items,
        status: c.status,
        cartonType: c.cartonType,
        weightKg: c.weightKg,
        lengthCm: c.lengthCm,
        widthCm: c.widthCm,
        heightCm: c.heightCm,
        trackingNumber: c.trackingNumber,
        note: c.note,
      );

  Carton _withLabel(Carton c, String? label) => Carton(
        id: c.id,
        cartonNo: c.cartonNo,
        label: label,
        items: c.items,
        status: c.status,
        cartonType: c.cartonType,
        weightKg: c.weightKg,
        lengthCm: c.lengthCm,
        widthCm: c.widthCm,
        heightCm: c.heightCm,
        trackingNumber: c.trackingNumber,
        note: c.note,
      );

  /// The last carton measurements written: (cartonId, weightKg, lengthCm,
  /// widthCm, heightCm, cartonType, trackingNumber).
  (int, double?, double?, double?, double?, String?, String?)?
      lastCartonMeasurements;

  int? lastClosedCartonId;
  int? lastReopenedCartonId;

  @override
  Future<ApiResult<bool>> setCartonMeasurements(
    int cartonId, {
    double? weightKg,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    String? cartonType,
    String? trackingNumber,
  }) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    lastCartonMeasurements = (
      cartonId,
      weightKg,
      lengthCm,
      widthCm,
      heightCm,
      cartonType,
      trackingNumber,
    );
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> closeCarton(int cartonId) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    lastClosedCartonId = cartonId;
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> reopenCarton(int cartonId) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    lastReopenedCartonId = cartonId;
    return const ApiSuccess(true);
  }

  /// What parcels() returns — set by a test, empty by default (a shipment
  /// that has not shipped yet has nothing to show here).
  List<ShipmentParcel> parcelsFixture = const [];

  @override
  Future<ApiResult<List<ShipmentParcel>>> parcels(int planId) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    return ApiSuccess(parcelsFixture);
  }
}

/// In-memory stand-in for the stock-ops backend. It mirrors the server's two
/// rules that the UI actually depends on: a blind session withholds system
/// quantities while it is open, and completing one leaves uncounted lines alone
/// instead of treating them as zero.
class FakeStockOpsRepository implements StockOpsRepository {
  FakeStockOpsRepository({
    this.adjustmentLog = const [],
    StockCount? count,
  }) : _count = count;

  final List<StockAdjustment> adjustmentLog;
  StockCount? _count;

  /// The warehouse the last write was scoped to.
  int? lastWarehouseId;

  /// The warehouse the last read was scoped to (null = all warehouses).
  int? lastListWarehouseId;

  /// The last adjustment posted, signed as the UI built it.
  int? lastDelta;

  /// The reason the last adjustment carried.
  AdjustReason? lastReason;

  /// When set, every mutating call (adjust/startCount/recordLine/
  /// completeCount/cancelCount) fails with this message instead of
  /// succeeding — e.g. to simulate a permission-denied RPC response.
  String? failWith;

  StockCount get session => _count!;

  StockCount _masked(StockCount c) {
    final hide = c.isBlind && c.isOpen;
    if (!hide) return c;
    return StockCount(
      id: c.id,
      status: c.status,
      warehouseId: c.warehouseId,
      warehouseName: c.warehouseName,
      isBlind: c.isBlind,
      hideSystem: true,
      note: c.note,
      lines: [
        for (final l in c.lines)
          StockCountLine(
            id: l.id,
            janCode: l.janCode,
            productName: l.productName,
            countedQuantity: l.countedQuantity,
          ),
      ],
    );
  }

  @override
  Future<ApiResult<List<StockAdjustment>>> adjustments(
      {int? warehouseId}) async {
    lastListWarehouseId = warehouseId;
    return ApiSuccess(adjustmentLog);
  }

  @override
  Future<ApiResult<StockAdjustment>> adjust({
    required int warehouseId,
    required String janCode,
    required int delta,
    required AdjustReason reason,
    String? note,
    String? productName,
  }) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    lastWarehouseId = warehouseId;
    lastDelta = delta;
    lastReason = reason;
    return ApiSuccess(StockAdjustment(
      id: 1,
      janCode: janCode,
      quantityDelta: delta,
      reason: reason,
      note: note,
    ));
  }

  @override
  Future<ApiResult<List<StockCount>>> counts(
      {int? warehouseId, String? status}) async {
    lastListWarehouseId = warehouseId;
    return ApiSuccess(_count == null ? const [] : [_masked(_count!)]);
  }

  @override
  Future<ApiResult<StockCount>> count(int id) async =>
      ApiSuccess(_masked(_count!));

  @override
  Future<ApiResult<StockCount>> startCount({
    required int warehouseId,
    bool blind = true,
    String? note,
  }) async {
    lastWarehouseId = warehouseId;
    return ApiSuccess(_masked(_count!));
  }

  @override
  Future<ApiResult<StockCount>> recordLine(
      int countId, int lineId, int counted) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    final c = _count!;
    _count = StockCount(
      id: c.id,
      status: c.status,
      warehouseId: c.warehouseId,
      warehouseName: c.warehouseName,
      isBlind: c.isBlind,
      note: c.note,
      lines: [
        for (final l in c.lines)
          if (l.id == lineId)
            StockCountLine(
              id: l.id,
              janCode: l.janCode,
              productName: l.productName,
              systemQuantity: l.systemQuantity,
              countedQuantity: counted,
              variance: l.systemQuantity == null
                  ? null
                  : counted - l.systemQuantity!,
            )
          else
            l,
      ],
    );
    return ApiSuccess(_masked(_count!));
  }

  @override
  Future<ApiResult<CompletedCount>> completeCount(int countId,
      {String? note}) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    final c = _count!;
    // Uncounted lines keep their frozen quantity: not counted is not zero.
    final counted = c.lines.where((l) => l.isCounted).toList();
    _count = StockCount(
      id: c.id,
      status: CountStatus.completed,
      warehouseId: c.warehouseId,
      warehouseName: c.warehouseName,
      isBlind: c.isBlind,
      note: c.note,
      lines: c.lines,
    );
    final adjusted = counted.where((l) => (l.variance ?? 0) != 0).toList();
    return ApiSuccess(CompletedCount(
      _count!,
      CountSummary(
        adjustedLines: adjusted.length,
        netChange: adjusted.fold(0, (s, l) => s + (l.variance ?? 0)),
        uncountedLines: c.lines.length - counted.length,
      ),
    ));
  }

  @override
  Future<ApiResult<StockCount>> cancelCount(int countId) async {
    final c = _count!;
    _count = StockCount(
      id: c.id,
      status: CountStatus.cancelled,
      warehouseId: c.warehouseId,
      isBlind: c.isBlind,
      lines: c.lines,
    );
    return ApiSuccess(_count!);
  }
}

/// In-memory stand-in for the picking backend. Mirrors the two server rules
/// the UI depends on: picked/planned derives PICKED/SHORT/OVER per task, and
/// completing a list refuses while any task is still untouched.
class FakePickingRepository implements PickingRepository {
  FakePickingRepository({required PickList list, bool started = true})
      : _list = list,
        _started = started;

  PickList _list;

  /// False until [start] is called: [lists] returns nothing until then, so a
  /// test can assert the index screen was empty before starting a pick.
  bool _started;

  /// Set when complete() was rejected because tasks were still pending.
  bool refusedIncomplete = false;

  /// The last quantity/bin recordPick() was called with.
  int? lastRecordedQuantity;
  int? lastRecordedBinId;

  /// When set, start() fails with this message instead of succeeding — e.g.
  /// to simulate a permission-denied RPC response (pick.confirm).
  String? failWith;

  /// Set by a test to control what candidatesFor() advises.
  PickCandidates? candidatesResult;

  int _nextItemId = 1;

  /// The last call to recordPickItem()/removePickItem().
  int? lastRecordedItemTaskId;
  int? lastRecordedItemQuantity;
  String? lastRecordedItemLotCode;
  int? lastRemovedItemId;

  PickTaskStatus _statusFor(int planned, int? picked) {
    if (picked == null) return PickTaskStatus.pending;
    if (picked == planned) return PickTaskStatus.picked;
    return picked < planned ? PickTaskStatus.short : PickTaskStatus.over;
  }

  @override
  Future<ApiResult<List<PickList>>> lists({int? warehouseId, String? status}) async =>
      ApiSuccess(!_started || (status != null && _list.status.wire != status)
          ? const []
          : [_list]);

  @override
  Future<ApiResult<PickList>> show(int id) async => ApiSuccess(_list);

  @override
  Future<ApiResult<PickList>> start(int shipmentPlanId, {String? note}) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    _started = true;
    return ApiSuccess(_list);
  }

  @override
  Future<ApiResult<PickList>> recordPick(
    int taskId, {
    required int quantity,
    int? binId,
    String? note,
  }) async {
    lastRecordedQuantity = quantity;
    lastRecordedBinId = binId;
    _list = PickList(
      id: _list.id,
      shipmentPlanId: _list.shipmentPlanId,
      shipmentNumber: _list.shipmentNumber,
      customerName: _list.customerName,
      warehouseId: _list.warehouseId,
      usesLocations: _list.usesLocations,
      status: _list.status,
      tasks: [
        for (final t in _list.tasks)
          if (t.id == taskId)
            PickTask(
              id: t.id,
              janCode: t.janCode,
              productName: t.productName,
              plannedQuantity: t.plannedQuantity,
              pickedQuantity: quantity,
              variance: quantity - t.plannedQuantity,
              status: _statusFor(t.plannedQuantity, quantity),
              binId: binId,
              binCode: binId == null ? null : t.binCode,
            )
          else
            t,
      ],
    );
    return ApiSuccess(_list);
  }

  @override
  Future<ApiResult<CompletedPickList>> complete(int pickListId) async {
    if (_list.pendingTasks > 0) {
      refusedIncomplete = true;
      return const ApiFailure(
          message: 'pick list still has unpicked line(s)', statusCode: 422);
    }
    _list = PickList(
      id: _list.id,
      shipmentPlanId: _list.shipmentPlanId,
      shipmentNumber: _list.shipmentNumber,
      customerName: _list.customerName,
      warehouseId: _list.warehouseId,
      usesLocations: _list.usesLocations,
      status: PickListStatus.picked,
      tasks: _list.tasks,
    );
    final short = _list.tasks.where((t) => t.status == PickTaskStatus.short).length;
    final over = _list.tasks.where((t) => t.status == PickTaskStatus.over).length;
    return ApiSuccess(CompletedPickList(
      _list,
      PickSummary(
        tasks: _list.tasks.length,
        pickedUnits: _list.tasks.fold(0, (s, t) => s + (t.pickedQuantity ?? 0)),
        plannedUnits: _list.tasks.fold(0, (s, t) => s + t.plannedQuantity),
        shortLines: short,
        overLines: over,
      ),
    ));
  }

  @override
  Future<ApiResult<PickList>> cancel(int pickListId) async {
    _list = PickList(
      id: _list.id,
      shipmentPlanId: _list.shipmentPlanId,
      status: PickListStatus.cancelled,
      tasks: _list.tasks,
    );
    return ApiSuccess(_list);
  }

  @override
  Future<ApiResult<PickCandidates>> candidatesFor(int taskId) async =>
      ApiSuccess(candidatesResult ??
          const PickCandidates(rule: 'FIFO', requested: 0, short: 0));

  @override
  Future<ApiResult<PickList>> recordPickItem(
    int taskId, {
    required int quantity,
    String? lotCode,
    String? serialNumber,
    int? binId,
    int? stockUnitId,
    String? note,
  }) async {
    lastRecordedItemTaskId = taskId;
    lastRecordedItemQuantity = quantity;
    lastRecordedItemLotCode = lotCode;
    final item = PickTaskItem(
      id: _nextItemId++,
      quantity: quantity,
      lotCode: lotCode,
      serialNumber: serialNumber,
      binId: binId,
      stockUnitId: stockUnitId,
      note: note,
      createdAt: DateTime.now(),
    );
    _list = PickList(
      id: _list.id,
      shipmentPlanId: _list.shipmentPlanId,
      shipmentNumber: _list.shipmentNumber,
      customerName: _list.customerName,
      warehouseId: _list.warehouseId,
      usesLocations: _list.usesLocations,
      status: _list.status,
      tasks: [
        for (final t in _list.tasks)
          if (t.id == taskId)
            _withItems(t, [...t.items, item], binId: binId ?? t.binId)
          else
            t,
      ],
    );
    return ApiSuccess(_list);
  }

  @override
  Future<ApiResult<PickList>> removePickItem(int itemId, {required int pickListId}) async {
    lastRemovedItemId = itemId;
    _list = PickList(
      id: _list.id,
      shipmentPlanId: _list.shipmentPlanId,
      shipmentNumber: _list.shipmentNumber,
      customerName: _list.customerName,
      warehouseId: _list.warehouseId,
      usesLocations: _list.usesLocations,
      status: _list.status,
      tasks: [
        for (final t in _list.tasks)
          if (t.items.any((i) => i.id == itemId))
            _withItems(t, t.items.where((i) => i.id != itemId).toList())
          else
            t,
      ],
    );
    return ApiSuccess(_list);
  }

  PickTask _withItems(PickTask t, List<PickTaskItem> items, {int? binId}) {
    final pickedQuantity =
        items.isEmpty ? null : items.fold(0, (s, i) => s + i.quantity);
    return PickTask(
      id: t.id,
      janCode: t.janCode,
      productId: t.productId,
      productName: t.productName,
      plannedQuantity: t.plannedQuantity,
      pickedQuantity: pickedQuantity,
      variance: pickedQuantity == null ? null : pickedQuantity - t.plannedQuantity,
      status: _statusFor(t.plannedQuantity, pickedQuantity),
      binId: binId ?? t.binId,
      binCode: t.binCode,
      note: t.note,
      pickedAt: t.pickedAt,
      pickingRule: t.pickingRule,
      items: items,
    );
  }
}

/// In-memory stand-in for the transfer backend. Mirrors the server's state
/// machine (spec §16) closely enough for a screen test: wrong-state calls are
/// refused with the same shape as a real RPC error, completing picking or
/// receiving refuses while any line is untouched, and stock only ever moves
/// (conceptually — this fake just tracks it) at those two completions.
class FakeTransferRepository implements TransferRepository {
  FakeTransferRepository({required TransferOrder order}) : _order = order;

  TransferOrder _order;

  /// Set whenever an action was rejected for being called in the wrong state.
  String? lastRefusal;

  /// When set, create() fails with this message instead of succeeding — e.g.
  /// to simulate a permission-denied RPC response (transfer.create).
  String? failWith;

  TransferOrder _copyWith({
    TransferStatus? status,
    List<TransferLine>? lines,
  }) =>
      TransferOrder(
        id: _order.id,
        transferNumber: _order.transferNumber,
        sourceWarehouseId: _order.sourceWarehouseId,
        sourceWarehouseName: _order.sourceWarehouseName,
        destinationWarehouseId: _order.destinationWarehouseId,
        destinationWarehouseName: _order.destinationWarehouseName,
        status: status ?? _order.status,
        note: _order.note,
        lines: lines ?? _order.lines,
      );

  ApiResult<TransferOrder> _transition(TransferStatus from, TransferStatus to) {
    if (_order.status != from) {
      lastRefusal = 'transfer is ${_order.status.wire}';
      return ApiFailure(message: lastRefusal!, statusCode: 400);
    }
    _order = _copyWith(status: to);
    return ApiSuccess(_order);
  }

  @override
  Future<ApiResult<List<TransferOrder>>> list({int? warehouseId, String? status}) async =>
      ApiSuccess(status == null || _order.status.wire == status ? [_order] : const []);

  @override
  Future<ApiResult<TransferOrder>> show(int id) async => ApiSuccess(_order);

  @override
  Future<ApiResult<TransferOrder>> create({
    required int sourceWarehouseId,
    required int destinationWarehouseId,
    required List<TransferLineDraft> lines,
    String? note,
  }) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    return ApiSuccess(_order);
  }

  @override
  Future<ApiResult<TransferOrder>> submit(int id) async =>
      _transition(TransferStatus.draft, TransferStatus.pendingApproval);

  @override
  Future<ApiResult<TransferOrder>> approve(int id) async =>
      _transition(TransferStatus.pendingApproval, TransferStatus.approved);

  @override
  Future<ApiResult<TransferOrder>> reject(int id, {String? reason}) async =>
      _transition(TransferStatus.pendingApproval, TransferStatus.rejected);

  @override
  Future<ApiResult<TransferOrder>> cancel(int id) async {
    if (!_order.status.isCancellable) {
      lastRefusal = 'transfer is ${_order.status.wire}';
      return ApiFailure(message: lastRefusal!, statusCode: 400);
    }
    _order = _copyWith(status: TransferStatus.cancelled);
    return ApiSuccess(_order);
  }

  @override
  Future<ApiResult<TransferOrder>> startPicking(int id) async =>
      _transition(TransferStatus.approved, TransferStatus.picking);

  @override
  Future<ApiResult<TransferOrder>> recordPick(int lineId, int quantity) async {
    _order = _copyWith(lines: [
      for (final l in _order.lines)
        if (l.id == lineId)
          TransferLine(
            id: l.id,
            janCode: l.janCode,
            productName: l.productName,
            requestedQuantity: l.requestedQuantity,
            pickedQuantity: quantity,
            pickVariance: quantity - l.requestedQuantity,
          )
        else
          l,
    ]);
    return ApiSuccess(_order);
  }

  @override
  Future<ApiResult<TransferOrder>> completePicking(int id) async {
    if (_order.unpickedLines > 0) {
      lastRefusal = 'transfer still has unpicked line(s)';
      return ApiFailure(message: lastRefusal!, statusCode: 400);
    }
    return _transition(TransferStatus.picking, TransferStatus.inTransit);
  }

  @override
  Future<ApiResult<TransferOrder>> startReceiving(int id) async =>
      _transition(TransferStatus.inTransit, TransferStatus.receiving);

  @override
  Future<ApiResult<TransferOrder>> recordReceipt(int lineId, int quantity) async {
    _order = _copyWith(lines: [
      for (final l in _order.lines)
        if (l.id == lineId)
          TransferLine(
            id: l.id,
            janCode: l.janCode,
            productName: l.productName,
            requestedQuantity: l.requestedQuantity,
            pickedQuantity: l.pickedQuantity,
            pickVariance: l.pickVariance,
            receivedQuantity: quantity,
            receiveVariance: quantity - (l.pickedQuantity ?? 0),
          )
        else
          l,
    ]);
    return ApiSuccess(_order);
  }

  @override
  Future<ApiResult<CompletedTransfer>> completeReceiving(int id) async {
    if (_order.unreceivedLines > 0) {
      lastRefusal = 'transfer still has unreceived line(s)';
      return const ApiFailure(
          message: 'transfer still has unreceived line(s)', statusCode: 400);
    }
    _order = _copyWith(status: TransferStatus.completed);
    final loss = _order.lines.where((l) => (l.receiveVariance ?? 0) < 0).length;
    return ApiSuccess(CompletedTransfer(
      _order,
      TransferReceiveSummary(
        lines: _order.lines.length,
        pickedUnits: _order.lines.fold(0, (s, l) => s + (l.pickedQuantity ?? 0)),
        receivedUnits: _order.lines.fold(0, (s, l) => s + (l.receivedQuantity ?? 0)),
        lossLines: loss,
      ),
    ));
  }
}

/// Audit trail stub. [entries] are filtered by event type for list(), the
/// same way the real RPC filters server-side.
class FakeAuditRepository implements AuditRepository {
  FakeAuditRepository(this.entries, {this.types = const []});
  final List<AuditEntry> entries;
  final List<String> types;

  /// The warehouse the last list() call was scoped to (null = all warehouses).
  int? lastWarehouseId;

  @override
  Future<ApiResult<List<AuditEntry>>> list({
    int? warehouseId,
    String? entityType,
    String? eventType,
    DateTime? since,
    int limit = 100,
  }) async {
    lastWarehouseId = warehouseId;
    return ApiSuccess(eventType == null
        ? entries
        : entries.where((e) => e.eventType == eventType).toList());
  }

  @override
  Future<ApiResult<List<String>>> eventTypes() async => ApiSuccess(types);

  @override
  Future<ApiResult<List<AuditEntry>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  }) async =>
      ApiSuccess(entries
          .where((e) => e.entityType == entityType && e.entityId == entityId)
          .toList());
}

/// Admin stub. [users] is the roster `list_app_users` would return; [roles]
/// is the role catalog. Assign/revoke mutate an in-memory copy of [users] so
/// a screen test can assert the change stuck without a real backend.
class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository(List<AppUserSummary> users, {this.roles = const []})
      : _users = List.of(users);

  List<AppUserSummary> _users;
  final List<RoleOption> roles;

  /// Set to make [listUsers] fail, so a test can exercise the permission-
  /// denied path a non-admin actually hits (the RPC itself is the real gate).
  String? failListUsersWith;

  @override
  Future<ApiResult<List<AppUserSummary>>> listUsers() async {
    if (failListUsersWith != null) {
      return ApiFailure(message: failListUsersWith!, statusCode: 403);
    }
    return ApiSuccess(_users);
  }

  @override
  Future<ApiResult<List<RoleOption>>> listRoles() async => ApiSuccess(roles);

  @override
  Future<ApiResult<bool>> assignRole(String userId, String roleCode) async {
    final role = roles.firstWhere((r) => r.code == roleCode);
    _users = [
      for (final u in _users)
        if (u.id == userId)
          AppUserSummary(
            id: u.id,
            name: u.name,
            email: u.email,
            status: u.status,
            createdAt: u.createdAt,
            roles: [...u.roles, UserRoleTag(code: role.code, name: role.name)],
            warehouseIds: u.warehouseIds,
          )
        else
          u,
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> revokeRole(String userId, String roleCode) async {
    _users = [
      for (final u in _users)
        if (u.id == userId)
          AppUserSummary(
            id: u.id,
            name: u.name,
            email: u.email,
            status: u.status,
            createdAt: u.createdAt,
            roles: u.roles.where((r) => r.code != roleCode).toList(),
            warehouseIds: u.warehouseIds,
          )
        else
          u,
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> assignWarehouse(String userId, int warehouseId) async {
    _users = [
      for (final u in _users)
        if (u.id == userId)
          AppUserSummary(
            id: u.id,
            name: u.name,
            email: u.email,
            status: u.status,
            createdAt: u.createdAt,
            roles: u.roles,
            warehouseIds: [...u.warehouseIds, warehouseId],
          )
        else
          u,
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> revokeWarehouse(String userId, int warehouseId) async {
    _users = [
      for (final u in _users)
        if (u.id == userId)
          AppUserSummary(
            id: u.id,
            name: u.name,
            email: u.email,
            status: u.status,
            createdAt: u.createdAt,
            roles: u.roles,
            warehouseIds: u.warehouseIds.where((id) => id != warehouseId).toList(),
          )
        else
          u,
    ];
    return const ApiSuccess(true);
  }
}

/// Connector registry stub. [connectors] is what `list_connectors` would
/// return; toggling mutates an in-memory copy so a screen test can assert
/// the switch stuck.
class FakeConnectorRepository implements ConnectorRepository {
  FakeConnectorRepository(List<Connector> connectors) : _connectors = List.of(connectors);

  List<Connector> _connectors;

  @override
  Future<ApiResult<List<Connector>>> list() async => ApiSuccess(_connectors);

  @override
  Future<ApiResult<bool>> setEnabled(String code, bool enabled) async {
    _connectors = [
      for (final c in _connectors)
        if (c.code == code)
          Connector(
            code: c.code,
            name: c.name,
            kind: c.kind,
            enabled: enabled,
            note: c.note,
            lastRun: c.lastRun,
          )
        else
          c,
    ];
    return const ApiSuccess(true);
  }
}

/// AI-review stub. [entries] is what `list_ai_analysis` would return for the
/// requested status; confirm/reject remove the entry from the in-memory list
/// (mirroring the real PENDING_REVIEW-only listing) so a screen test can
/// assert it disappears.
class FakeAiReviewRepository implements AiReviewRepository {
  FakeAiReviewRepository(List<AiAnalysisEntry> entries) : _entries = List.of(entries);

  List<AiAnalysisEntry> _entries;

  /// The id + reason the last reject() call was made with.
  int? lastRejectedId;
  String? lastRejectReason;

  @override
  Future<ApiResult<List<AiAnalysisEntry>>> list({String status = 'PENDING_REVIEW'}) async =>
      ApiSuccess(_entries.where((e) => e.status == status).toList());

  @override
  Future<ApiResult<bool>> confirm(int id) async {
    _entries = _entries.where((e) => e.id != id).toList();
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> reject(int id, {String? reason}) async {
    lastRejectedId = id;
    lastRejectReason = reason;
    _entries = _entries.where((e) => e.id != id).toList();
    return const ApiSuccess(true);
  }
}

/// Attachment stub. [attachments] is what `attachments_for` would return for
/// one entity; upload() appends in-memory rather than touching Storage, so a
/// screen test can assert the thumbnail strip updates, and withdraw() marks
/// rather than removes — which is what 0070 does.
class FakeAttachmentRepository implements AttachmentRepository {
  FakeAttachmentRepository({List<Attachment> attachments = const []})
      : _attachments = List.of(attachments);

  List<Attachment> _attachments;

  /// The arguments of the last upload() call, for assertions.
  String? lastUploadEntityType;
  String? lastUploadEntityId;
  String? lastUploadFileName;
  AttachmentKind? lastUploadKind;
  String? lastUploadCaption;
  int? lastUploadWarehouseId;

  /// The arguments of the last withdraw() call.
  int? lastWithdrawnId;
  String? lastWithdrawReason;

  /// Whether the last list() call asked for withdrawn rows too.
  bool? lastListIncludedWithdrawn;

  @override
  Future<ApiResult<List<Attachment>>> list(
    String entityType,
    String entityId, {
    bool includeWithdrawn = false,
  }) async {
    lastListIncludedWithdrawn = includeWithdrawn;
    return ApiSuccess(_attachments
        .where((a) => a.entityType == entityType && a.entityId == entityId)
        .where((a) => includeWithdrawn || !a.isWithdrawn)
        .toList());
  }

  @override
  Future<ApiResult<Attachment>> upload({
    required String entityType,
    required String entityId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    AttachmentKind kind = AttachmentKind.photo,
    String? caption,
    int? warehouseId,
  }) async {
    lastUploadEntityType = entityType;
    lastUploadEntityId = entityId;
    lastUploadFileName = fileName;
    lastUploadKind = kind;
    lastUploadCaption = caption;
    lastUploadWarehouseId = warehouseId;
    final attachment = Attachment(
      id: _attachments.length + 1,
      entityType: entityType,
      entityId: entityId,
      storagePath: '$entityType/$entityId/$fileName',
      contentType: contentType,
      createdAt: DateTime.now(),
      kind: kind,
      caption: caption,
      byteSize: bytes.length,
      warehouseId: warehouseId,
    );
    _attachments = [..._attachments, attachment];
    return ApiSuccess(attachment);
  }

  @override
  Future<ApiResult<bool>> withdraw(int attachmentId, {String? reason}) async {
    lastWithdrawnId = attachmentId;
    lastWithdrawReason = reason;
    _attachments = [
      for (final a in _attachments)
        if (a.id == attachmentId)
          Attachment(
            id: a.id,
            entityType: a.entityType,
            entityId: a.entityId,
            storagePath: a.storagePath,
            contentType: a.contentType,
            createdAt: a.createdAt,
            kind: a.kind,
            caption: a.caption,
            byteSize: a.byteSize,
            warehouseId: a.warehouseId,
            withdrawnAt: DateTime.now(),
          )
        else
          a,
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<String>> signedUrl(String storagePath) async =>
      ApiSuccess('https://example.test/$storagePath');
}

/// Product master stub. [products] is what `list_products` would return;
/// create/update/setStatus mutate an in-memory copy so a screen test can
/// assert the change stuck.
class FakeProductRepository implements ProductRepository {
  FakeProductRepository({List<Product> products = const []})
      : _products = List.of(products);

  List<Product> _products;

  /// Set to make create() fail (e.g. duplicate JAN), mirroring the real RPC.
  String? failCreateWith;

  @override
  Future<ApiResult<List<Product>>> list(
      {String? search, String? status = 'active'}) async {
    return ApiSuccess(_products.where((p) {
      final statusOk = status == null || p.status == status;
      final searchOk = search == null ||
          search.isEmpty ||
          p.name.contains(search) ||
          p.janCode.contains(search);
      return statusOk && searchOk;
    }).toList());
  }

  @override
  Future<ApiResult<int>> create({
    required String janCode,
    required String name,
    String? category,
    double? price,
  }) async {
    if (failCreateWith != null) {
      return ApiFailure(message: failCreateWith!, statusCode: 400);
    }
    final id = _products.length + 1;
    _products = [
      ..._products,
      Product(id: id, janCode: janCode, name: name, category: category, price: price),
    ];
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<bool>> update({
    required int id,
    required String name,
    String? category,
    double? price,
  }) async {
    _products = [
      for (final p in _products)
        if (p.id == id)
          Product(
            id: p.id,
            janCode: p.janCode,
            name: name,
            category: category,
            price: price,
            status: p.status,
            pickingRule: p.pickingRule,
            requiresInspection: p.requiresInspection,
          )
        else
          p,
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> setStatus(int id, String status) async {
    _products = [
      for (final p in _products)
        if (p.id == id)
          Product(
            id: p.id,
            janCode: p.janCode,
            name: p.name,
            sku: p.sku,
            category: p.category,
            price: p.price,
            status: status,
            trackingMode: p.trackingMode,
            pickingRule: p.pickingRule,
            requiresInspection: p.requiresInspection,
            baseUom: p.baseUom,
            uoms: p.uoms,
            barcodes: p.barcodes,
          )
        else
          p,
    ];
    return const ApiSuccess(true);
  }

  /// The arguments of the last setIdentity() call, so a screen test can assert
  /// that the SKU and tracking mode went through `set_product_identity` and not
  /// through `update_product` (0057).
  ({int id, String? sku, TrackingMode? trackingMode})? lastIdentity;

  /// When set, setIdentity() fails with this message — the real RPC refuses a
  /// tracking mode that contradicts lots or serials already recorded (§37-15).
  String? failIdentityWith;

  @override
  Future<ApiResult<bool>> setIdentity({
    required int id,
    String? sku,
    TrackingMode? trackingMode,
  }) async {
    lastIdentity = (id: id, sku: sku, trackingMode: trackingMode);
    if (failIdentityWith != null) {
      return ApiFailure(message: failIdentityWith!, statusCode: 400);
    }
    _products = [
      for (final p in _products)
        if (p.id == id)
          Product(
            id: p.id,
            janCode: p.janCode,
            name: p.name,
            // '' clears, null leaves alone — the same rule the RPC follows.
            sku: sku == null ? p.sku : (sku.isEmpty ? null : sku),
            category: p.category,
            price: p.price,
            status: p.status,
            trackingMode: trackingMode ?? p.trackingMode,
            pickingRule: p.pickingRule,
            requiresInspection: p.requiresInspection,
            baseUom: p.baseUom,
            uoms: p.uoms,
            barcodes: p.barcodes,
          )
        else
          p,
    ];
    return const ApiSuccess(true);
  }

  /// The last setPickingRule() call, so a screen test can assert the rule went
  /// through its own RPC.
  ({int productId, String rule})? lastPickingRule;

  @override
  Future<ApiResult<bool>> setPickingRule({
    required int productId,
    required String rule,
  }) async {
    lastPickingRule = (productId: productId, rule: rule);
    _products = [
      for (final p in _products)
        if (p.id == productId)
          Product(
            id: p.id,
            janCode: p.janCode,
            name: p.name,
            sku: p.sku,
            category: p.category,
            price: p.price,
            status: p.status,
            trackingMode: p.trackingMode,
            pickingRule: rule,
            requiresInspection: p.requiresInspection,
            baseUom: p.baseUom,
            uoms: p.uoms,
            barcodes: p.barcodes,
          )
        else
          p,
    ];
    return const ApiSuccess(true);
  }

  /// The last setInspectionRequirement() call.
  ({int productId, bool requiresInspection})? lastInspectionRequirement;

  @override
  Future<ApiResult<bool>> setInspectionRequirement({
    required int productId,
    required bool requiresInspection,
  }) async {
    lastInspectionRequirement =
        (productId: productId, requiresInspection: requiresInspection);
    _products = [
      for (final p in _products)
        if (p.id == productId)
          Product(
            id: p.id,
            janCode: p.janCode,
            name: p.name,
            sku: p.sku,
            category: p.category,
            price: p.price,
            status: p.status,
            trackingMode: p.trackingMode,
            pickingRule: p.pickingRule,
            requiresInspection: requiresInspection,
            baseUom: p.baseUom,
            uoms: p.uoms,
            barcodes: p.barcodes,
          )
        else
          p,
    ];
    return const ApiSuccess(true);
  }

  /// Barcodes added through addBarcode(), newest last.
  final List<({int productId, String barcode, String? uomCode, bool isPrimary})>
      addedBarcodes = [];

  @override
  Future<ApiResult<int>> addBarcode({
    required int productId,
    required String barcode,
    String barcodeType = 'JAN',
    int quantityPerScan = 1,
    bool isPrimary = false,
    String? uomCode,
    String? note,
  }) async {
    addedBarcodes.add((
      productId: productId,
      barcode: barcode,
      uomCode: uomCode,
      isPrimary: isPrimary,
    ));
    return ApiSuccess(addedBarcodes.length);
  }

  final List<int> removedBarcodeIds = [];

  @override
  Future<ApiResult<bool>> removeBarcode(int barcodeId) async {
    removedBarcodeIds.add(barcodeId);
    return const ApiSuccess(true);
  }

  final List<({int productId, String uomCode, double factor})> setUoms = [];

  @override
  Future<ApiResult<bool>> setUom({
    required int productId,
    required String uomCode,
    required double conversionFactor,
  }) async {
    setUoms.add((
      productId: productId,
      uomCode: uomCode,
      factor: conversionFactor,
    ));
    return const ApiSuccess(true);
  }

  /// The unit vocabulary a pack size is chosen from; the real one is seeded with
  /// sixteen units (0059).
  List<Uom> uomVocabulary = const [
    Uom(code: 'PCS', name: '個'),
    Uom(code: 'BOX', name: '箱'),
    Uom(code: 'CASE', name: 'ケース'),
  ];

  @override
  Future<ApiResult<List<Uom>>> listUoms() async => ApiSuccess(uomVocabulary);

  /// The last removeUom() call, and an optional failure to simulate the
  /// server's refusal (base unit, or a barcode still names it).
  final List<({int productId, String uomCode})> removedUoms = [];
  String? failRemoveUomWith;

  @override
  Future<ApiResult<bool>> removeUom({
    required int productId,
    required String uomCode,
  }) async {
    if (failRemoveUomWith != null) {
      return ApiFailure(message: failRemoveUomWith!, statusCode: 400);
    }
    removedUoms.add((productId: productId, uomCode: uomCode));
    return const ApiSuccess(true);
  }

  /// Lots and serials a test wants the detail screen to show. Keyed by product,
  /// so one fake can hold a tracked and an untracked product at once.
  Map<int, List<ProductLot>> lotsByProduct = const {};
  Map<int, List<ProductSerial>> serialsByProduct = const {};

  /// The status [serials] was last filtered by, so a test can assert the filter
  /// reached the RPC rather than being applied client-side.
  String? lastSerialStatus;

  @override
  Future<ApiResult<List<ProductLot>>> lots(int productId) async =>
      ApiSuccess(lotsByProduct[productId] ?? const []);

  @override
  Future<ApiResult<List<ProductSerial>>> serials(int productId,
      {String? status}) async {
    lastSerialStatus = status;
    final all = serialsByProduct[productId] ?? const <ProductSerial>[];
    return ApiSuccess(
        status == null ? all : all.where((s) => s.status == status).toList());
  }

  /// The last setSerialStatus() call, so a screen test can assert the change
  /// went through its own RPC.
  ({int serialId, String status, String? note})? lastSerialStatusChange;

  /// When set, setSerialStatus() fails with this message instead of succeeding.
  String? failSerialStatusWith;

  @override
  Future<ApiResult<bool>> setSerialStatus({
    required int serialId,
    required String status,
    String? note,
  }) async {
    lastSerialStatusChange = (serialId: serialId, status: status, note: note);
    if (failSerialStatusWith != null) {
      return ApiFailure(message: failSerialStatusWith!, statusCode: 400);
    }
    serialsByProduct = {
      for (final entry in serialsByProduct.entries)
        entry.key: [
          for (final s in entry.value)
            if (s.id == serialId)
              ProductSerial(
                id: s.id,
                serialNumber: s.serialNumber,
                status: status,
                lotId: s.lotId,
                lotCode: s.lotCode,
                createdAt: s.createdAt,
                note: note ?? s.note,
              )
            else
              s,
        ],
    };
    return const ApiSuccess(true);
  }

  /// Per-warehouse settings, keyed the way the table is: (warehouse, product).
  Map<(int, int), WarehouseProduct> warehouseProducts = {};

  /// The arguments of the last setWarehouseProduct() call.
  ({int warehouseId, int productId, String? locationCode, int? reorderPoint,
      String? putawayRule})? lastWarehouseProduct;

  /// When set, setWarehouseProduct() fails with this message — the real RPC
  /// refuses `max < min` and a location from another warehouse.
  String? failWarehouseProductWith;

  @override
  Future<ApiResult<WarehouseProduct?>> warehouseSettings({
    required int warehouseId,
    required int productId,
  }) async =>
      ApiSuccess(warehouseProducts[(warehouseId, productId)]);

  @override
  Future<ApiResult<WarehouseProduct?>> setWarehouseProduct({
    required int warehouseId,
    required int productId,
    String? defaultLocationCode,
    int? minStock,
    int? maxStock,
    int? reorderPoint,
    int? pickPriority,
    String? putawayRule,
    int? preferredSupplierId,
    int? leadTimeDays,
    String? note,
  }) async {
    lastWarehouseProduct = (
      warehouseId: warehouseId,
      productId: productId,
      locationCode: defaultLocationCode,
      reorderPoint: reorderPoint,
      putawayRule: putawayRule,
    );
    if (failWarehouseProductWith != null) {
      return ApiFailure(message: failWarehouseProductWith!, statusCode: 400);
    }
    final current = warehouseProducts[(warehouseId, productId)];
    final saved = WarehouseProduct(
      warehouseId: warehouseId,
      productId: productId,
      // '' clears, null leaves alone — the RPC's own rule.
      defaultLocationCode: defaultLocationCode == null
          ? current?.defaultLocationCode
          : (defaultLocationCode.isEmpty ? null : defaultLocationCode),
      minStock: minStock ?? current?.minStock,
      maxStock: maxStock ?? current?.maxStock,
      reorderPoint: reorderPoint ?? current?.reorderPoint,
      pickPriority: pickPriority ?? current?.pickPriority ?? 100,
      putawayRule: putawayRule ?? current?.putawayRule ?? 'MANUAL',
      preferredSupplierId: preferredSupplierId ?? current?.preferredSupplierId,
      leadTimeDays: leadTimeDays ?? current?.leadTimeDays,
      note: note ?? current?.note,
      onHand: current?.onHand ?? 0,
      available: current?.available ?? 0,
    );
    warehouseProducts[(warehouseId, productId)] = saved;
    return ApiSuccess(saved);
  }

  @override
  Future<ApiResult<bool>> clearWarehouseProduct({
    required int warehouseId,
    required int productId,
  }) async =>
      ApiSuccess(warehouseProducts.remove((warehouseId, productId)) != null);
}

/// Purchase order stub. Mirrors the real RPCs' state-machine transitions
/// (DRAFT -> SUBMITTED -> APPROVED -> COMPLETED, or REJECTED/CANCELLED) so a
/// screen test exercises the same rules the backend enforces.
class FakePurchaseOrderRepository implements PurchaseOrderRepository {
  FakePurchaseOrderRepository({List<PurchaseOrder> orders = const []})
      : _orders = List.of(orders);

  List<PurchaseOrder> _orders;

  /// When set, create() fails with this message instead of succeeding — e.g.
  /// to simulate a permission-denied RPC response.
  String? failWith;

  PurchaseOrder _copyWith(PurchaseOrder o, {PurchaseOrderStatus? status}) => PurchaseOrder(
        id: o.id,
        status: status ?? o.status,
        poNumber: o.poNumber,
        supplierId: o.supplierId,
        supplierName: o.supplierName,
        warehouseId: o.warehouseId,
        warehouseName: o.warehouseName,
        orderDate: o.orderDate,
        expectedDate: o.expectedDate,
        note: o.note,
        createdAt: o.createdAt,
        lines: o.lines,
        lineCount: o.lineCount,
        totalAmount: o.totalAmount,
      );

  ApiResult<bool> _transition(int id, PurchaseOrderStatus from, PurchaseOrderStatus to) {
    final order = _orders.firstWhere((o) => o.id == id);
    if (order.status != from) {
      return ApiFailure(message: 'purchase order is ${order.status.wire}', statusCode: 400);
    }
    _orders = [
      for (final o in _orders) if (o.id == id) _copyWith(o, status: to) else o,
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<PurchaseOrder>>> list({int? warehouseId, String? status}) async =>
      ApiSuccess(_orders
          .where((o) =>
              (warehouseId == null || o.warehouseId == warehouseId) &&
              (status == null || o.status.wire == status))
          .toList());

  @override
  Future<ApiResult<PurchaseOrder>> show(int id) async =>
      ApiSuccess(_orders.firstWhere((o) => o.id == id));

  @override
  Future<ApiResult<int>> create({
    required String supplierName,
    required int warehouseId,
    required List<PurchaseOrderLineDraft> lines,
    int? supplierId,
    DateTime? expectedDate,
    String? note,
  }) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    final id = _orders.isEmpty
        ? 1
        : _orders.map((o) => o.id).reduce((a, b) => a > b ? a : b) + 1;
    final order = PurchaseOrder(
      id: id,
      status: PurchaseOrderStatus.draft,
      poNumber: 'PO-${id.toString().padLeft(6, '0')}',
      supplierId: supplierId,
      supplierName: supplierName,
      warehouseId: warehouseId,
      expectedDate: expectedDate,
      note: note,
      createdAt: DateTime.now(),
      lines: [
        for (var i = 0; i < lines.length; i++)
          PurchaseOrderLine(
            id: i + 1,
            janCode: lines[i].janCode,
            productName: lines[i].productName,
            quantity: lines[i].quantity,
            unitPrice: lines[i].unitPrice,
          ),
      ],
    );
    _orders = [..._orders, order];
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<bool>> submit(int id) async =>
      _transition(id, PurchaseOrderStatus.draft, PurchaseOrderStatus.submitted);

  @override
  Future<ApiResult<bool>> approve(int id) async =>
      _transition(id, PurchaseOrderStatus.submitted, PurchaseOrderStatus.approved);

  @override
  Future<ApiResult<bool>> reject(int id, {String? reason}) async =>
      _transition(id, PurchaseOrderStatus.submitted, PurchaseOrderStatus.rejected);

  @override
  Future<ApiResult<bool>> cancel(int id) async {
    final order = _orders.firstWhere((o) => o.id == id);
    if (![
      PurchaseOrderStatus.draft,
      PurchaseOrderStatus.submitted,
      PurchaseOrderStatus.approved,
    ].contains(order.status)) {
      return ApiFailure(
          message: 'purchase order is ${order.status.wire}', statusCode: 400);
    }
    return _transition(id, order.status, PurchaseOrderStatus.cancelled);
  }

  @override
  Future<ApiResult<bool>> complete(int id) async =>
      _transition(id, PurchaseOrderStatus.approved, PurchaseOrderStatus.completed);
}

/// Sales order stub. Mirrors the real RPCs' state-machine transitions
/// (DRAFT -> SUBMITTED -> APPROVED -> COMPLETED, or REJECTED/CANCELLED) so a
/// screen test exercises the same rules the backend enforces.
class FakeSalesOrderRepository implements SalesOrderRepository {
  FakeSalesOrderRepository({List<SalesOrder> orders = const []})
      : _orders = List.of(orders);

  List<SalesOrder> _orders;

  /// What approve() reports (0073). Defaults to reserving every line cleanly;
  /// a test overrides this to exercise the shortfall path.
  SalesOrderApprovalResult approvalResult =
      const SalesOrderApprovalResult(reservedLines: 1, skipped: []);
  int? lastApprovedId;

  /// What createShipment() reports; a test overrides shipmentPlanId to assert
  /// on the id it navigates to.
  ShipmentFromSalesOrderResult shipmentResult =
      const ShipmentFromSalesOrderResult(
          shipmentPlanId: 900, lines: 1, reservationsRelinked: 1);
  int? lastShipmentCreatedFor;

  SalesOrder _copyWith(
    SalesOrder o, {
    SalesOrderStatus? status,
    int? shipmentPlanId,
  }) =>
      SalesOrder(
        id: o.id,
        status: status ?? o.status,
        soNumber: o.soNumber,
        customerId: o.customerId,
        customerName: o.customerName,
        warehouseId: o.warehouseId,
        warehouseName: o.warehouseName,
        orderDate: o.orderDate,
        requestedShipDate: o.requestedShipDate,
        note: o.note,
        createdAt: o.createdAt,
        lines: o.lines,
        lineCount: o.lineCount,
        totalAmount: o.totalAmount,
        shipmentPlanId: shipmentPlanId ?? o.shipmentPlanId,
        reservations: o.reservations,
      );

  ApiResult<bool> _transition(int id, SalesOrderStatus from, SalesOrderStatus to) {
    final order = _orders.firstWhere((o) => o.id == id);
    if (order.status != from) {
      return ApiFailure(message: 'sales order is ${order.status.wire}', statusCode: 400);
    }
    _orders = [
      for (final o in _orders) if (o.id == id) _copyWith(o, status: to) else o,
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<SalesOrder>>> list({int? warehouseId, String? status}) async =>
      ApiSuccess(_orders
          .where((o) =>
              (warehouseId == null || o.warehouseId == warehouseId) &&
              (status == null || o.status.wire == status))
          .toList());

  @override
  Future<ApiResult<SalesOrder>> show(int id) async =>
      ApiSuccess(_orders.firstWhere((o) => o.id == id));

  @override
  Future<ApiResult<int>> create({
    required String customerName,
    required int warehouseId,
    required List<SalesOrderLineDraft> lines,
    int? customerId,
    DateTime? requestedShipDate,
    String? note,
  }) async {
    final id = _orders.isEmpty
        ? 1
        : _orders.map((o) => o.id).reduce((a, b) => a > b ? a : b) + 1;
    final order = SalesOrder(
      id: id,
      status: SalesOrderStatus.draft,
      soNumber: 'SO-${id.toString().padLeft(6, '0')}',
      customerId: customerId,
      customerName: customerName,
      warehouseId: warehouseId,
      requestedShipDate: requestedShipDate,
      note: note,
      createdAt: DateTime.now(),
      lines: [
        for (var i = 0; i < lines.length; i++)
          SalesOrderLine(
            id: i + 1,
            janCode: lines[i].janCode,
            productName: lines[i].productName,
            quantity: lines[i].quantity,
            unitPrice: lines[i].unitPrice,
          ),
      ],
    );
    _orders = [..._orders, order];
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<bool>> submit(int id) async =>
      _transition(id, SalesOrderStatus.draft, SalesOrderStatus.submitted);

  @override
  Future<ApiResult<SalesOrderApprovalResult>> approve(int id) async {
    lastApprovedId = id;
    final r = _transition(id, SalesOrderStatus.submitted, SalesOrderStatus.approved);
    return r.when(
      success: (_) => ApiSuccess(approvalResult),
      failure: (f) => ApiFailure(message: f.message, statusCode: f.statusCode),
    );
  }

  @override
  Future<ApiResult<ShipmentFromSalesOrderResult>> createShipment(int id) async {
    lastShipmentCreatedFor = id;
    final order = _orders.firstWhere((o) => o.id == id);
    if (order.status != SalesOrderStatus.approved) {
      return ApiFailure(message: 'sales order is ${order.status.wire}', statusCode: 400);
    }
    _orders = [
      for (final o in _orders)
        if (o.id == id)
          _copyWith(o, shipmentPlanId: shipmentResult.shipmentPlanId)
        else
          o,
    ];
    return ApiSuccess(shipmentResult);
  }

  @override
  Future<ApiResult<bool>> reject(int id, {String? reason}) async =>
      _transition(id, SalesOrderStatus.submitted, SalesOrderStatus.rejected);

  @override
  Future<ApiResult<bool>> cancel(int id) async {
    final order = _orders.firstWhere((o) => o.id == id);
    if (![
      SalesOrderStatus.draft,
      SalesOrderStatus.submitted,
      SalesOrderStatus.approved,
    ].contains(order.status)) {
      return ApiFailure(
          message: 'sales order is ${order.status.wire}', statusCode: 400);
    }
    return _transition(id, order.status, SalesOrderStatus.cancelled);
  }

  @override
  Future<ApiResult<bool>> complete(int id) async =>
      _transition(id, SalesOrderStatus.approved, SalesOrderStatus.completed);
}

/// Trading partner stub. [partners] is what `list_trading_partners` would
/// return; create/update/setStatus mutate an in-memory copy so a screen test
/// can assert the change stuck.
class FakeTradingPartnerRepository implements TradingPartnerRepository {
  FakeTradingPartnerRepository({List<TradingPartner> partners = const []})
      : _partners = List.of(partners);

  List<TradingPartner> _partners;

  /// Set to make create() fail (e.g. duplicate code), mirroring the real RPC.
  String? failCreateWith;

  @override
  Future<ApiResult<List<TradingPartner>>> list({
    PartnerKind? kind,
    String? search,
    String? status = 'active',
  }) async {
    return ApiSuccess(_partners.where((p) {
      final statusOk = status == null || p.status == status;
      final kindOk = kind == null || p.kind == kind || p.kind == PartnerKind.both;
      final searchOk = search == null ||
          search.isEmpty ||
          p.name.contains(search) ||
          (p.code ?? '').contains(search);
      return statusOk && kindOk && searchOk;
    }).toList());
  }

  @override
  Future<ApiResult<int>> create({
    required String name,
    PartnerKind kind = PartnerKind.supplier,
    String? code,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? paymentTerms,
    String? notes,
  }) async {
    if (failCreateWith != null) {
      return ApiFailure(message: failCreateWith!, statusCode: 400);
    }
    final id = _partners.length + 1;
    _partners = [
      ..._partners,
      TradingPartner(
        id: id,
        name: name,
        kind: kind,
        code: code,
        contactName: contactName,
        phone: phone,
        email: email,
        address: address,
        paymentTerms: paymentTerms,
        notes: notes,
      ),
    ];
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<bool>> update({
    required int id,
    required String name,
    PartnerKind kind = PartnerKind.supplier,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? paymentTerms,
    String? notes,
  }) async {
    _partners = [
      for (final p in _partners)
        if (p.id == id)
          TradingPartner(
            id: p.id,
            name: name,
            kind: kind,
            code: p.code,
            contactName: contactName,
            phone: phone,
            email: email,
            address: address,
            paymentTerms: paymentTerms,
            notes: notes,
            status: p.status,
          )
        else
          p,
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> setStatus(int id, String status) async {
    _partners = [
      for (final p in _partners)
        if (p.id == id)
          TradingPartner(
            id: p.id,
            name: p.name,
            kind: p.kind,
            code: p.code,
            contactName: p.contactName,
            phone: p.phone,
            email: p.email,
            address: p.address,
            paymentTerms: p.paymentTerms,
            notes: p.notes,
            status: status,
          )
        else
          p,
    ];
    return const ApiSuccess(true);
  }
}

/// Work order stub. Mirrors the real RPCs' state-machine transitions
/// (DRAFT -> IN_PROGRESS -> COMPLETED, or CANCELLED) so a screen test
/// exercises the same rules the backend enforces. Unlike purchase/sales
/// order fakes, this doesn't need to simulate stock movement — the screen
/// only cares that complete() succeeds and flips the status.
class FakeWorkOrderRepository implements WorkOrderRepository {
  FakeWorkOrderRepository({List<WorkOrder> orders = const []})
      : _orders = List.of(orders);

  List<WorkOrder> _orders;

  WorkOrder _copyWith(WorkOrder o, {WorkOrderStatus? status}) => WorkOrder(
        id: o.id,
        status: status ?? o.status,
        woNumber: o.woNumber,
        warehouseId: o.warehouseId,
        warehouseName: o.warehouseName,
        outputJanCode: o.outputJanCode,
        outputProductName: o.outputProductName,
        outputQuantity: o.outputQuantity,
        note: o.note,
        startedAt: o.startedAt,
        completedAt: o.completedAt,
        createdAt: o.createdAt,
        components: o.components,
        componentCount: o.componentCount,
      );

  ApiResult<bool> _transition(int id, WorkOrderStatus from, WorkOrderStatus to) {
    final order = _orders.firstWhere((o) => o.id == id);
    if (order.status != from) {
      return ApiFailure(message: 'work order is ${order.status.wire}', statusCode: 400);
    }
    _orders = [
      for (final o in _orders) if (o.id == id) _copyWith(o, status: to) else o,
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<WorkOrder>>> list({int? warehouseId, String? status}) async =>
      ApiSuccess(_orders
          .where((o) =>
              (warehouseId == null || o.warehouseId == warehouseId) &&
              (status == null || o.status.wire == status))
          .toList());

  @override
  Future<ApiResult<WorkOrder>> show(int id) async =>
      ApiSuccess(_orders.firstWhere((o) => o.id == id));

  @override
  Future<ApiResult<int>> create({
    required int warehouseId,
    required String outputJanCode,
    required int outputQuantity,
    required List<WorkOrderComponentDraft> components,
    String? outputProductName,
    String? note,
  }) async {
    final id = _orders.isEmpty
        ? 1
        : _orders.map((o) => o.id).reduce((a, b) => a > b ? a : b) + 1;
    final order = WorkOrder(
      id: id,
      status: WorkOrderStatus.draft,
      woNumber: 'WO-${id.toString().padLeft(6, '0')}',
      warehouseId: warehouseId,
      outputJanCode: outputJanCode,
      outputProductName: outputProductName ?? '',
      outputQuantity: outputQuantity,
      note: note,
      createdAt: DateTime.now(),
      components: [
        for (var i = 0; i < components.length; i++)
          WorkOrderComponent(
            id: i + 1,
            janCode: components[i].janCode,
            productName: components[i].productName,
            quantityRequired: components[i].quantityRequired,
          ),
      ],
    );
    _orders = [..._orders, order];
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<bool>> start(int id) async =>
      _transition(id, WorkOrderStatus.draft, WorkOrderStatus.inProgress);

  @override
  Future<ApiResult<bool>> cancel(int id) async {
    final order = _orders.firstWhere((o) => o.id == id);
    if (![WorkOrderStatus.draft, WorkOrderStatus.inProgress].contains(order.status)) {
      return ApiFailure(
          message: 'work order is ${order.status.wire}', statusCode: 400);
    }
    return _transition(id, order.status, WorkOrderStatus.cancelled);
  }

  @override
  Future<ApiResult<bool>> complete(int id) async =>
      _transition(id, WorkOrderStatus.inProgress, WorkOrderStatus.completed);
}

/// Put-away stub (0038). [tasks] is the queue, [bins] the codes a scan can
/// resolve (keyed uppercase, as `bin_by_code` matches). `confirm` mirrors the
/// server: it lowers the task's pending quantity, refuses more than is
/// pending, and replays a repeated idempotency key instead of posting twice.
class FakePutawayRepository implements PutawayRepository {
  FakePutawayRepository({
    List<PutawayTask> tasks = const [],
    this.bins = const {},
  }) : _tasks = List.of(tasks);

  List<PutawayTask> _tasks;
  final Map<String, BinLocation> bins;

  /// Every confirm that actually posted, oldest first.
  final List<PutawayResult> confirmed = [];
  final Map<String, PutawayResult> _byKey = {};

  /// Which parcel the last confirm named (0069). Null status means "the
  /// shippable ones", which is what the server reads it as.
  String? lastLotCode;
  String? lastStatusCode;

  @override
  Future<ApiResult<List<PutawayTask>>> queue(int warehouseId) async =>
      ApiSuccess(_tasks);

  @override
  Future<ApiResult<BinLocation?>> binByCode(int warehouseId, String code) async =>
      ApiSuccess(bins[code.trim().toUpperCase()]);

  @override
  Future<ApiResult<PutawayResult>> confirm({
    required int warehouseId,
    required String janCode,
    required int binId,
    required int quantity,
    required String idempotencyKey,
    String? note,
    String? lotCode,
    String? statusCode,
  }) async {
    lastLotCode = lotCode;
    lastStatusCode = statusCode;
    final replay = _byKey[idempotencyKey];
    if (replay != null) {
      return ApiSuccess(PutawayResult(
        janCode: replay.janCode,
        quantity: replay.quantity,
        binCode: replay.binCode,
        binOnHand: replay.binOnHand,
        pendingAfter: replay.pendingAfter,
        replayed: true,
      ));
    }
    final task = _tasks.firstWhere((t) => t.janCode == janCode);
    if (quantity > task.pendingQuantity) {
      return const ApiFailure(message: 'awaits put-away');
    }
    final pendingAfter = task.pendingQuantity - quantity;
    _tasks = [
      for (final t in _tasks)
        if (t.janCode != janCode)
          t
        else if (pendingAfter > 0)
          // The parcel shrinks; nothing counts it twice. Since 0069 the queue
          // has no stored quantity to keep in step (§14).
          PutawayTask(
            janCode: t.janCode,
            productId: t.productId,
            productName: t.productName,
            pendingQuantity: pendingAfter,
            warehouseOnHand: t.warehouseOnHand,
            lotId: t.lotId,
            lotCode: t.lotCode,
            statusCode: t.statusCode,
            statusName: t.statusName,
            countsAvailable: t.countsAvailable,
            suggestions: t.suggestions,
          ),
    ];
    final result = PutawayResult(
      janCode: janCode,
      quantity: quantity,
      binCode: bins.values
              .firstWhere((b) => b.binId == binId,
                  orElse: () => const BinLocation(binId: 0, binCode: ''))
              .binCode,
      binOnHand: quantity,
      pendingAfter: pendingAfter,
    );
    _byKey[idempotencyKey] = result;
    confirmed.add(result);
    return ApiSuccess(result);
  }
}

/// Report builder stub. [rowsBySource] supplies the canned rows `run()`
/// returns per source; save/delete mutate an in-memory list of saved
/// definitions so a screen test can assert the change stuck.
class FakeReportRepository implements ReportRepository {
  FakeReportRepository({
    this.rowsBySource = const {},
    List<ReportDefinition> savedDefinitions = const [],
  }) : _saved = List.of(savedDefinitions);

  final Map<ReportSource, List<Map<String, dynamic>>> rowsBySource;
  List<ReportDefinition> _saved;

  /// The filters the last run() call was made with.
  Map<String, dynamic>? lastFilters;

  @override
  Future<ApiResult<ReportResult>> run(
    ReportSource source, {
    Map<String, dynamic> filters = const {},
    int limit = 500,
  }) async {
    lastFilters = filters;
    return ApiSuccess(ReportResult(source: source, rows: rowsBySource[source] ?? const []));
  }

  @override
  Future<ApiResult<List<ReportDefinition>>> listSaved() async => ApiSuccess(_saved);

  @override
  Future<ApiResult<int>> save({
    required String name,
    required ReportSource source,
    Map<String, dynamic> filters = const {},
  }) async {
    final id = _saved.length + 1;
    _saved = [
      ..._saved,
      ReportDefinition(id: id, name: name, source: source, filters: filters),
    ];
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<bool>> delete(int id) async {
    _saved = _saved.where((d) => d.id != id).toList();
    return const ApiSuccess(true);
  }
}

/// Search stub. Returns [results] for any non-empty query, records the
/// warehouse the last call was scoped to.
class FakeSearchRepository implements SearchRepository {
  FakeSearchRepository(this.results);
  final List<SearchResult> results;

  int? lastWarehouseId;
  String? lastQuery;

  @override
  Future<ApiResult<List<SearchResult>>> search(
    String query, {
    int? warehouseId,
    int limit = 8,
  }) async {
    lastQuery = query;
    lastWarehouseId = warehouseId;
    return ApiSuccess(results);
  }
}

/// Inventory-control stub: the attention lists Phase A made possible (expiry,
/// reservations, over-allocation, replenishment). Each list is what the test
/// hands it; [releasedIds] records what a release actually asked for.
class FakeInventoryRepository implements InventoryRepository {
  FakeInventoryRepository({
    this.lots = const [],
    this.reservationList = const [],
    this.overAllocatedList = const [],
    this.suggestions = const [],
  });

  List<ExpiringLot> lots;
  List<Reservation> reservationList;
  List<OverAllocatedStock> overAllocatedList;
  List<ReplenishmentSuggestion> suggestions;

  /// The horizon the last expiringLots() call asked for.
  int? lastHorizon;

  /// The status filter the last reservations() call asked for. Distinct from
  /// "not called": a null *status* means every status.
  ({int? warehouseId, String? status})? lastReservationQuery;

  final List<int> releasedIds = [];

  /// When set, releaseReservation() fails with this message — the real RPC
  /// refuses a second release.
  String? failReleaseWith;

  @override
  Future<ApiResult<List<ExpiringLot>>> expiringLots({
    int days = 30,
    bool includeExpired = true,
  }) async {
    lastHorizon = days;
    return ApiSuccess(lots);
  }

  @override
  Future<ApiResult<List<Reservation>>> reservations({
    int? warehouseId,
    int? productId,
    String? status = 'ACTIVE',
  }) async {
    lastReservationQuery = (warehouseId: warehouseId, status: status);
    return ApiSuccess(status == null
        ? reservationList
        : reservationList.where((r) => r.status == status).toList());
  }

  @override
  Future<ApiResult<List<OverAllocatedStock>>> overAllocated(
          {int? warehouseId}) async =>
      ApiSuccess(overAllocatedList);

  @override
  Future<ApiResult<bool>> releaseReservation(int reservationId,
      {String? note}) async {
    releasedIds.add(reservationId);
    if (failReleaseWith != null) {
      return ApiFailure(message: failReleaseWith!, statusCode: 400);
    }
    reservationList = [
      for (final r in reservationList)
        if (r.id == reservationId)
          Reservation(
            id: r.id,
            productId: r.productId,
            productName: r.productName,
            warehouseId: r.warehouseId,
            quantity: r.quantity,
            status: 'RELEASED',
            fulfilledQuantity: r.fulfilledQuantity,
            referenceType: r.referenceType,
            referenceId: r.referenceId,
          )
        else
          r,
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<ReplenishmentSuggestion>>> replenishment({
    int? warehouseId,
  }) async =>
      ApiSuccess(suggestions);
}

/// Location tree stub (0062). [roots] is what `location_tree` would return,
/// nested; [types] is the §8 vocabulary a form chooses from.
class FakeLocationRepository implements LocationRepository {
  FakeLocationRepository({
    this.roots = const [],
    List<LocationType>? types,
  }) : typeList = types ??
            const [
              LocationType(code: 'STORAGE', name: '保管'),
              LocationType(
                  code: 'RECEIVING',
                  name: '入荷',
                  defaultPickable: false,
                  defaultReceivable: true,
                  defaultVirtual: true),
            ];

  List<Location> roots;
  final List<LocationType> typeList;

  /// Whether the last tree() call asked for switched-off nodes too.
  bool? lastIncludeInactive;
  int? lastWarehouseId;

  /// What create() was last asked for, so a test can assert the parent travelled
  /// as a *code* (which is what is printed on the rack) and not as an id.
  ({int warehouseId, String code, String type, String? parentCode})? lastCreated;

  /// What update() was last asked for; null fields mean "leave alone".
  ({int id, String? type, bool? isActive, String? parentCode})? lastUpdated;

  /// When set, create() fails with this message — the real RPC refuses a
  /// duplicate code, a parent in another warehouse and a cycle.
  String? failCreateWith;

  @override
  Future<ApiResult<List<Location>>> tree(
    int warehouseId, {
    bool includeInactive = false,
  }) async {
    lastWarehouseId = warehouseId;
    lastIncludeInactive = includeInactive;
    return ApiSuccess(roots);
  }

  @override
  Future<ApiResult<List<LocationType>>> types() async => ApiSuccess(typeList);

  /// What bin_stock_overview() would return, keyed by warehouse.
  List<BinStock> binStock = const [];

  @override
  Future<ApiResult<List<BinStock>>> binStockOverview(int warehouseId) async {
    lastWarehouseId = warehouseId;
    return ApiSuccess(binStock);
  }

  @override
  Future<ApiResult<int>> create({
    required int warehouseId,
    required String code,
    String? name,
    String locationType = 'STORAGE',
    String? parentCode,
    String? barcode,
    bool? pickable,
    bool? receivable,
    bool? shipping,
    bool? quarantine,
    bool? isVirtual,
  }) async {
    lastCreated = (
      warehouseId: warehouseId,
      code: code,
      type: locationType,
      parentCode: parentCode,
    );
    if (failCreateWith != null) {
      return ApiFailure(message: failCreateWith!, statusCode: 400);
    }
    return const ApiSuccess(99);
  }

  @override
  Future<ApiResult<bool>> update({
    required int locationId,
    String? name,
    String? locationType,
    String? parentCode,
    String? barcode,
    bool? isActive,
    bool? pickable,
    bool? receivable,
    bool? shipping,
    bool? quarantine,
  }) async {
    lastUpdated = (
      id: locationId,
      type: locationType,
      isActive: isActive,
      parentCode: parentCode,
    );
    return const ApiSuccess(true);
  }
}

/// The exception queue (0071). Records what was asked of it so a test can check
/// that the *decision* was sent and that nothing pretended to move stock.
class FakeExceptionRepository implements ExceptionRepository {
  FakeExceptionRepository({
    this.exceptions = const [],
    ExceptionSummary? summaryValue,
  }) : summaryValue = summaryValue ??
            ExceptionSummary(
              open: exceptions.where((e) => e.isOpen).length,
              blockers: exceptions.where((e) => e.isOpen && e.isBlocker).length,
            );

  List<WarehouseException> exceptions;
  ExceptionSummary summaryValue;

  String? lastCategory;
  bool? lastIncludeClosed;
  int? lastWarehouseId;
  int? acknowledgedId;
  ({int id, ExceptionResolution resolution, String? note})? lastResolution;
  ({int id, String? reason})? lastCancel;
  String? failResolveWith;

  @override
  Future<ApiResult<List<WarehouseException>>> open({
    int? warehouseId,
    String? category,
    bool includeClosed = false,
    int limit = 100,
  }) async {
    lastWarehouseId = warehouseId;
    lastCategory = category;
    lastIncludeClosed = includeClosed;
    final rows = includeClosed
        ? exceptions
        : exceptions.where((e) => e.isOpen).toList();
    return ApiSuccess(category == null
        ? rows
        : rows.where((e) => e.category == category).toList());
  }

  @override
  Future<ApiResult<ExceptionSummary>> summary({int? warehouseId}) async =>
      ApiSuccess(summaryValue);

  @override
  Future<ApiResult<bool>> acknowledge(int exceptionId) async {
    acknowledgedId = exceptionId;
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> resolve(
    int exceptionId,
    ExceptionResolution resolution, {
    String? note,
  }) async {
    if (failResolveWith != null) {
      return ApiFailure(message: failResolveWith!, statusCode: 400);
    }
    lastResolution = (id: exceptionId, resolution: resolution, note: note);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> cancel(int exceptionId, {String? reason}) async {
    lastCancel = (id: exceptionId, reason: reason);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<int>> raise({
    required String exceptionType,
    required int warehouseId,
    String? note,
    int? reconciliationId,
    int? productId,
    String? janCode,
    int? quantity,
    int? receiptItemId,
    int? inspectionId,
  }) async =>
      const ApiSuccess(1);
}

/// A repository that is always signed in as one fixed [user] — for the few
/// screens (e.g. wave assignment) that compare the caller's own id against a
/// record's, and have no other way to be told who "the caller" is in a test.
class _FakeAuthUserRepository implements AuthRepository {
  _FakeAuthUserRepository(this.user);
  final AuthUser user;

  @override
  Future<ApiResult<AuthUser>> login(String email, String password) async =>
      ApiSuccess(user);
  @override
  Future<ApiResult<AuthUser>> currentUser() async => ApiSuccess(user);
  @override
  Future<void> logout() async {}
}

/// A real [AuthController] wired to [_FakeAuthUserRepository], so its own
/// startup restore (`_restore()`, which every `AuthController` runs on
/// construction) lands on [user] instead of hitting the network. Override
/// `authControllerProvider` with this rather than a bare `StateNotifier<
/// AuthState>`: the provider's type is `StateNotifierProvider<AuthController,
/// AuthState>`, so only an actual `AuthController` satisfies it.
AuthController fakeAuthControllerFor(AuthUser user) => AuthController(
      _FakeAuthUserRepository(user),
      SupabaseTokenRefresher(
        storage: SupabaseSessionStorage(_FakeSecureKeyValueStore()),
        refresh: (_) async => null,
      ),
    );

/// §15's wave picking stub. [waves] is what `pick_wave_index` would return;
/// create()/assign()/complete()/cancel() mutate an in-memory copy so a screen
/// test can assert the change stuck.
class FakePickWaveRepository implements PickWaveRepository {
  FakePickWaveRepository({List<PickWave> waves = const []}) : _waves = List.of(waves);

  List<PickWave> _waves;

  /// What create() reports; a test overrides this to exercise the skipped path.
  CreatePickWaveResult createResult = const CreatePickWaveResult(
      waveId: 1, code: 'WV-000001', pickListIds: [], skipped: []);
  List<int>? lastCreateShipmentPlanIds;

  /// The sheet plan() returns; keyed by nothing — one wave at a time in tests.
  WavePickPlan? sheet;

  String? lastAssignedUserId;
  int? lastAssignedWaveId;

  /// What assign() should say the assignee's display name is — the server
  /// would resolve this from the id; the fake has to be told.
  String? assignedToNameForAssign;

  PickWave _copyWith(PickWave w, {PickWaveStatus? status, String? assignedTo}) =>
      PickWave(
        id: w.id,
        code: w.code,
        warehouseId: w.warehouseId,
        warehouseName: w.warehouseName,
        status: status ?? w.status,
        assignedTo: assignedTo,
        assignedToName: assignedTo == null ? null : assignedToNameForAssign,
        priority: w.priority,
        note: w.note,
        createdAt: w.createdAt,
        startedAt: w.startedAt,
        completedAt: w.completedAt,
        taskCount: w.taskCount,
        pickedCount: w.pickedCount,
        listCount: w.listCount,
        lists: w.lists,
      );

  @override
  Future<ApiResult<List<PickWave>>> index({int? warehouseId, String? status}) async =>
      ApiSuccess(_waves
          .where((w) =>
              (warehouseId == null || w.warehouseId == warehouseId) &&
              (status == null || w.status.wire == status))
          .toList());

  @override
  Future<ApiResult<PickWave>> detail(int id) async =>
      ApiSuccess(_waves.firstWhere((w) => w.id == id));

  @override
  Future<ApiResult<CreatePickWaveResult>> create({
    required int warehouseId,
    required List<int> shipmentPlanIds,
    String? code,
    String? assignedTo,
    int priority = 100,
    String? note,
  }) async {
    lastCreateShipmentPlanIds = shipmentPlanIds;
    return ApiSuccess(createResult);
  }

  @override
  Future<ApiResult<PickWave>> assign(int id, {String? userId}) async {
    lastAssignedWaveId = id;
    lastAssignedUserId = userId;
    _waves = [
      for (final w in _waves)
        if (w.id == id)
          _copyWith(w,
              status: userId != null && w.status == PickWaveStatus.open
                  ? PickWaveStatus.picking
                  : null,
              assignedTo: userId)
        else
          w,
    ];
    return ApiSuccess(_waves.firstWhere((w) => w.id == id));
  }

  @override
  Future<ApiResult<WaveOutcome>> complete(int id) async {
    final w = _waves.firstWhere((x) => x.id == id);
    if (w.pickedCount < w.taskCount) {
      return ApiFailure(message: 'wave $id still has unpicked line(s)', statusCode: 400);
    }
    _waves = [
      for (final x in _waves)
        if (x.id == id) _copyWith(x, status: PickWaveStatus.done) else x,
    ];
    return ApiSuccess(WaveOutcome(waveId: id, status: 'DONE', count: w.lists.length));
  }

  @override
  Future<ApiResult<WaveOutcome>> cancel(int id) async {
    final w = _waves.firstWhere((x) => x.id == id);
    _waves = [
      for (final x in _waves)
        if (x.id == id) _copyWith(x, status: PickWaveStatus.cancelled) else x,
    ];
    return ApiSuccess(WaveOutcome(waveId: id, status: 'CANCELLED', count: w.lists.length));
  }

  @override
  Future<ApiResult<WavePickPlan>> plan(int id) async =>
      ApiSuccess(sheet ?? WavePickPlan(waveId: id));
}
