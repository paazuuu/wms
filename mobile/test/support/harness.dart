import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/company/application/company_providers.dart';
import 'package:wms_mobile/features/company/data/company_repository.dart';
import 'package:wms_mobile/features/company/domain/company_profile.dart';
import 'package:wms_mobile/features/evidence/application/evidence_providers.dart';
import 'package:wms_mobile/features/evidence/data/evidence_repository.dart';
import 'package:wms_mobile/features/evidence/domain/import_document.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/providers.dart';
import 'package:wms_mobile/core/theme/app_theme.dart';
import 'package:wms_mobile/core/offline/pending_sync.dart';
import 'package:wms_mobile/core/storage/supabase_session_storage.dart';
import 'package:wms_mobile/features/documents/data/documents_repository.dart';
import 'package:wms_mobile/features/product_library/application/product_library_providers.dart';
import 'package:wms_mobile/features/product_library/application/product_naming_providers.dart';
import 'package:wms_mobile/features/product_library/data/product_naming_repository.dart';
import 'package:wms_mobile/features/product_library/domain/product_naming.dart';
import 'package:wms_mobile/features/product_library/data/product_image_repository.dart';
import 'package:wms_mobile/features/product_library/domain/product_image.dart';
import 'package:wms_mobile/features/documents/domain/documents.dart';
import 'package:wms_mobile/features/documents/presentation/documents_labels.dart';
import 'package:wms_mobile/features/admin/data/admin_repository.dart';
import 'package:wms_mobile/features/admin/domain/app_user_summary.dart';
import 'package:wms_mobile/features/ai_review/data/ai_review_repository.dart';
import 'package:wms_mobile/features/ai_review/domain/ai_analysis_entry.dart';
import 'package:wms_mobile/features/connectors/data/connector_repository.dart';
import 'package:wms_mobile/features/connectors/domain/connector.dart';
import 'package:wms_mobile/features/delivery/data/delivery_repository.dart';
import 'package:wms_mobile/features/inbound/application/inbound_providers.dart';
import 'package:wms_mobile/features/inbound/data/inbound_repository.dart';
import 'package:wms_mobile/features/inbound/domain/inbound.dart';
import 'package:wms_mobile/features/exceptions/data/exception_repository.dart';
import 'package:wms_mobile/features/exceptions/domain/warehouse_exception.dart';
import 'package:wms_mobile/features/delivery/data/stock_repository.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan.dart';
import 'package:wms_mobile/features/delivery/domain/receipt.dart';
import 'package:wms_mobile/features/delivery/domain/receipt_detail.dart';
import 'package:wms_mobile/features/delivery/domain/stock_item.dart';
import 'package:wms_mobile/features/delivery/domain/stock_movement.dart';
import 'package:wms_mobile/features/delivery/domain/stock_position.dart';
import 'package:wms_mobile/features/home/application/role_dashboard_providers.dart';
import 'package:wms_mobile/features/home/data/dashboard_repository.dart';
import 'package:wms_mobile/features/home/data/role_dashboard_repository.dart';
import 'package:wms_mobile/features/home/domain/role_dashboards.dart';
import 'package:wms_mobile/features/home/domain/dashboard_metrics.dart';
import 'package:wms_mobile/features/qc/application/attachment_providers.dart';
import 'package:wms_mobile/features/shipment/application/packaging_providers.dart';
import 'package:wms_mobile/features/shipment/data/packaging_repository.dart';
import 'package:wms_mobile/features/shipment/domain/packaging.dart';
import 'package:wms_mobile/features/qc/data/attachment_repository.dart';
import 'package:wms_mobile/features/qc/application/qc_scan_mode.dart';
import 'package:wms_mobile/features/qc/data/inspection_repository.dart';
import 'package:wms_mobile/features/qc/domain/attachment.dart';
import 'package:wms_mobile/features/qc/domain/held_stock.dart';
import 'package:wms_mobile/features/qc/domain/bulk_inspection.dart';
import 'package:wms_mobile/features/qc/domain/delivery_note.dart';
import 'package:wms_mobile/features/qc/domain/inspection.dart';
import 'package:wms_mobile/features/picking_ops/data/picking_repository.dart';
import 'package:wms_mobile/features/picking_ops/domain/pick_list.dart';
import 'package:wms_mobile/features/partners/application/trading_partner_providers.dart';
import 'package:wms_mobile/features/partners/data/trading_partner_repository.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/data/product_repository.dart';
import 'package:wms_mobile/features/product/domain/data_quality.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/price_book/application/price_book_providers.dart';
import 'package:wms_mobile/features/price_book/data/price_book_repository.dart';
import 'package:wms_mobile/features/price_book/domain/price_book.dart';
import 'package:wms_mobile/features/inventory/data/inventory_repository.dart';
import 'package:wms_mobile/features/inventory/domain/reservation.dart';
import 'package:wms_mobile/features/inventory/domain/stock_discrepancy.dart';
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
import 'package:wms_mobile/features/demand/application/demand_providers.dart';
import 'package:wms_mobile/features/home/application/dashboard_providers.dart';
import 'package:wms_mobile/features/home/data/dashboard_charts_repository.dart';
import 'package:wms_mobile/features/home/domain/dashboard_charts.dart';
import 'package:wms_mobile/features/virtual_stock/application/virtual_stock_providers.dart';
import 'package:wms_mobile/features/virtual_stock/data/virtual_stock_repository.dart';
import 'package:wms_mobile/features/virtual_stock/domain/virtual_stock.dart';
import 'package:wms_mobile/features/product/domain/supplier_product_name.dart';
import 'package:wms_mobile/features/warehouse_context/data/warehouse_role_repository.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse_role.dart';
import 'package:wms_mobile/features/demand/data/demand_repository.dart';
import 'package:wms_mobile/features/demand/domain/open_demand.dart';
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
import 'package:wms_mobile/features/notation/application/notation_providers.dart';
import 'package:wms_mobile/features/notation/data/notation_repository.dart';
import 'package:wms_mobile/features/notation/domain/notation.dart';
import 'package:wms_mobile/features/supply_chain/application/supply_chain_providers.dart';
import 'package:wms_mobile/features/supply_chain/data/supply_chain_repository.dart';
import 'package:wms_mobile/features/supply_chain/domain/supply_chain.dart';
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
/// The inspection scan-mode setting over an in-memory store (0101), for a
/// test that builds its own container.
Override fakeScanModeOverride() => scanCountsPieceProvider
    .overrideWith((ref) => ScanCountsPieceController(_FakeSecureKeyValueStore()));

/// The device store for the offline queue and read cache (spec §58), in memory.
SecureKeyValueStore fakeSecureStore() => _FakeSecureKeyValueStore();

/// The remembered dashboard view (0102) over an in-memory store.
Override fakeDashboardViewOverride() => dashboardViewProvider
    .overrideWith((ref) => DashboardViewController(_FakeSecureKeyValueStore()));

List<Override> _defaultOverrides() => [
      fakeScanModeOverride(),
      // 仕入先ファイル起点の入荷 (0134), in memory.
      inboundRepositoryProvider.overrideWithValue(FakeInboundRepository()),
      fakeDashboardViewOverride(),
      roleDashboardRepositoryProvider.overrideWithValue(FakeRoleDashboardRepository()),
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
      demandRepositoryProvider.overrideWithValue(FakeDemandRepository()),
      warehouseRoleRepositoryProvider.overrideWithValue(FakeWarehouseRoleRepository()),
      virtualStockRepositoryProvider.overrideWithValue(FakeVirtualStockRepository()),
      dashboardChartsRepositoryProvider.overrideWithValue(FakeDashboardChartsRepository()),
      tradingPartnerRepositoryProvider
          .overrideWithValue(FakeTradingPartnerRepository()),
      workOrderRepositoryProvider.overrideWithValue(FakeWorkOrderRepository()),
      reportRepositoryProvider.overrideWithValue(FakeReportRepository()),
      putawayRepositoryProvider.overrideWithValue(FakePutawayRepository()),
      pickWaveRepositoryProvider.overrideWithValue(FakePickWaveRepository()),
      notationRepositoryProvider.overrideWithValue(FakeNotationRepository()),
      // The supply chain layer is off unless a test turns it on (0107).
      scCanViewProvider.overrideWithValue(false),
      scCanManageProvider.overrideWithValue(false),
      // The offline queue lives in memory, and nobody may settle invoices
      // unless a test says so (0108).
      offlineStoreProvider.overrideWithValue(_FakeSecureKeyValueStore()),
      documentsCanManageProvider.overrideWithValue(false),
      // No product pictures unless a test adds some (0109).
      productImageRepositoryProvider.overrideWithValue(FakeProductImageRepository()),
      productLibraryCanManageProvider.overrideWithValue(false),
      productCanDeleteProvider.overrideWithValue(false),
      productCanLifecycleProvider.overrideWithValue(false),
      // Our product format (0111), in memory.
      productNamingRepositoryProvider.overrideWithValue(FakeProductNamingRepository()),
      // Boxes and shipping weights (0115), in memory.
      packagingRepositoryProvider.overrideWithValue(FakePackagingRepository()),
      // 価格台帳 (0124), empty unless a test fills it.
      priceBookRepositoryProvider.overrideWithValue(FakePriceBookRepository()),
      // Kept files (0132) and our company (0131), in memory.
      evidenceRepositoryProvider.overrideWithValue(FakeEvidenceRepository()),
      companyRepositoryProvider.overrideWithValue(FakeCompanyRepository()),
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
        // The app's own theme, so a style that breaks a layout (a button
        // asking for infinite width) fails here as it would in the app.
        theme: AppTheme.light(),
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
  Widget child, {
  bool canManageProducts = false,
}) async {
  // Product pictures (0109) are served from memory here even when the
  // caller's container predates them, so no row reaches for the network;
  // nobody manages products here, so the sign-in state is never read.
  final images = FakeProductImageRepository();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ProviderScope(
        overrides: [
          productImageRepositoryProvider.overrideWithValue(images),
          evidenceRepositoryProvider.overrideWithValue(FakeEvidenceRepository()),
          // What came in for a product (0135): nothing here.
          productInboundHistoryProvider.overrideWith((ref, productId) async => const ProductInboundHistory()),
          productFaceCacheProvider.overrideWith((ref) => ProductFaceCache(images)),
          // Managing products (0111's name builder) is off here, as in pumpApp.
          productLibraryCanManageProvider.overrideWithValue(canManageProducts),
          productCanDeleteProvider.overrideWithValue(false),
          productCanLifecycleProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ja'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: child,
        ),
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

  ({int id, DateTime date})? lastArrivedOn;

  @override
  Future<ApiResult<bool>> setReceiptArrivedOn(int reconciliationId, DateTime date) async {
    lastArrivedOn = (id: reconciliationId, date: date);
    return const ApiSuccess(true);
  }

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

  /// Plans deletePlan() removed (0116).
  final deleted = <int>[];

  @override
  Future<ApiResult<bool>> deletePlan(int id) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    deleted.add(id);
    plans.removeWhere((p) => p.id == id);
    return const ApiSuccess(true);
  }

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

  /// What recordReceiptItem() was last asked to add by hand.
  ({
    int reconciliationId,
    String janCode,
    int quantity,
    int? lineId,
    String? lotCode,
    String? locationCode,
  })? lastRecordedItem;
  String? failRecordItemWith;

  @override
  Future<ApiResult<bool>> recordReceiptItem({
    required int reconciliationId,
    required String janCode,
    required int quantity,
    int? lineId,
    String? lotCode,
    DateTime? expiry,
    String? serialNumber,
    String? locationCode,
    String? statusCode,
    String? note,
  }) async {
    lastRecordedItem = (
      reconciliationId: reconciliationId,
      janCode: janCode,
      quantity: quantity,
      lineId: lineId,
      lotCode: lotCode,
      locationCode: locationCode,
    );
    if (failRecordItemWith != null) {
      return ApiFailure(message: failRecordItemWith!, statusCode: 400);
    }
    return const ApiSuccess(true);
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
              productId: it.productId,
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
    // 0100: a line nobody judged is good by default and passes in full.
    inspection = Inspection(
      id: inspection.id,
      status: inspection.status,
      deliveryNumber: inspection.deliveryNumber,
      supplierName: inspection.supplierName,
      items: [
        for (final it in inspection.items)
          if (it.isChecked)
            it
          else
            InspectionItem(
              id: it.id,
              janCode: it.janCode,
              productName: it.productName,
              expectedQuantity: it.expectedQuantity,
              actualQuantity: it.actualQuantity,
              productId: it.productId,
              passedQuantity: it.countedQuantity ?? it.actualQuantity,
              failedQuantity: 0,
              discrepancy: it.discrepancy,
              result: QcResult.pass,
              countedQuantity: it.countedQuantity,
            ),
      ],
    );
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
  Future<ApiResult<List<HeldStock>>> heldStock({int? warehouseId, String? status}) async {
    lastHeldWarehouseId = warehouseId;
    lastHeldStatus = status;
    return ApiSuccess(status == null ? held : held.where((h) => h.statusCode == status).toList());
  }

  final List<({int itemId, int quantity, InspectionCountMode mode})> counts = [];
  ({int inspectionId, String jan, int quantity})? lastWrongItem;
  List<DeliveryNoteLine>? lastNoteLines;
  DeliveryNoteApplyResult? noteResult;

  @override
  Future<ApiResult<InspectionCount>> recordCount(int itemId, int quantity,
      {InspectionCountMode mode = InspectionCountMode.set}) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    counts.add((itemId: itemId, quantity: quantity, mode: mode));
    late InspectionCount out;
    inspection = Inspection(
      id: inspection.id,
      status: inspection.status,
      deliveryNumber: inspection.deliveryNumber,
      supplierName: inspection.supplierName,
      method: inspection.method,
      samplePercent: inspection.samplePercent,
      sampleMin: inspection.sampleMin,
      items: [
        for (final it in inspection.items)
          if (it.id == itemId)
            () {
              int? sampled = it.sampledQuantity;
              if (mode == InspectionCountMode.sample) {
                sampled = (sampled ?? 0) + quantity;
              }
              final int? counted = switch (mode) {
                InspectionCountMode.add => (it.countedQuantity ?? 0) + quantity,
                InspectionCountMode.check => it.noteQuantity ?? it.actualQuantity,
                InspectionCountMode.clear => null,
                InspectionCountMode.set => quantity,
                // The sample done: accepted as a tick would be (0104).
                InspectionCountMode.sample => it.countedQuantity ??
                    (sampled! >= (it.sampleQuantity ?? 1)
                        ? it.noteQuantity ?? it.actualQuantity
                        : null),
              };
              if (mode == InspectionCountMode.clear) sampled = null;
              out = InspectionCount(
                  itemId: it.id, counted: counted ?? 0, received: it.actualQuantity);
              return InspectionItem(
                id: it.id,
                janCode: it.janCode,
                productName: it.productName,
                expectedQuantity: it.expectedQuantity,
                actualQuantity: it.actualQuantity,
                passedQuantity: counted == null
                    ? 0
                    : (counted < it.actualQuantity ? counted : it.actualQuantity),
                failedQuantity: it.failedQuantity,
                discrepancy: it.discrepancy,
                result: counted == null ? QcResult.pending : QcResult.pass,
                countedQuantity: counted,
                noteQuantity: it.noteQuantity,
                noteProductName: it.noteProductName,
                productId: it.productId,
                productSku: it.productSku,
                productMaker: it.productMaker,
                srcJanCode: it.srcJanCode,
                srcProductCode: it.srcProductCode,
                srcProductName: it.srcProductName,
                srcMaker: it.srcMaker,
                convertedBy: it.convertedBy,
                sampleQuantity: it.sampleQuantity,
                sampledQuantity: sampled,
              );
            }()
          else
            it,
      ],
    );
    return ApiSuccess(out);
  }

  @override
  Future<ApiResult<DeliveryNoteApplyResult>> applyDeliveryNote(
      int inspectionId, List<DeliveryNoteLine> lines) async {
    lastNoteLines = lines;
    return ApiSuccess(noteResult ?? DeliveryNoteApplyResult(matched: lines.length));
  }

  @override
  Future<ApiResult<bool>> reportWrongItem(int inspectionId, String janCode,
      {int quantity = 1, String? note}) async {
    lastWrongItem = (inspectionId: inspectionId, jan: janCode, quantity: quantity);
    return const ApiSuccess(true);
  }

  ({int itemId, int productId, bool remember})? lastConvert;

  @override
  Future<ApiResult<bool>> convertItem(int itemId, int productId, {bool remember = true}) async {
    lastConvert = (itemId: itemId, productId: productId, remember: remember);
    return const ApiSuccess(true);
  }

  List<OpenInspectionLine> openLineList = const [];
  List<int>? lastPassed;
  BulkPassResult? passResult;

  @override
  Future<ApiResult<List<OpenInspectionLine>>> openLines({int? warehouseId}) async =>
      ApiSuccess(openLineList);

  @override
  Future<ApiResult<BulkPassResult>> passItems(List<int> itemIds, {String? note}) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    lastPassed = itemIds;
    openLineList = [for (final l in openLineList) if (!itemIds.contains(l.itemId)) l];
    return ApiSuccess(passResult ??
        BulkPassResult(items: itemIds.length, releasedToOk: itemIds.length));
  }

  String? lastHeldStatus;
  ({HeldStock row, HeldDisposition action, int quantity, String? note})? lastDisposition;

  @override
  Future<ApiResult<DispositionResult>> dispose(HeldStock row, HeldDisposition action,
      {required int quantity, String? note}) async {
    if (failWith != null) return ApiFailure(message: failWith!);
    lastDisposition = (row: row, action: action, quantity: quantity, note: note);
    return ApiSuccess(DispositionResult(quantity: quantity));
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
        sourceCountryCode: _order.sourceCountryCode,
        destinationCountryCode: _order.destinationCountryCode,
        crossBorder: _order.crossBorder,
        exports: _order.exports,
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
    // Like the RPC (0087): an export closes here, with nothing to receive.
    return _transition(TransferStatus.picking,
        _order.exports ? TransferStatus.exported : TransferStatus.inTransit);
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

  List<SupplierProductName> supplierNameList = [];
  ({int supplierId, int productId, String name, String? code})? lastSupplierName;
  final List<int> removedSupplierNameIds = [];

  @override
  Future<ApiResult<List<SupplierProductName>>> supplierNames(
          {int? productId, int? supplierId}) async =>
      ApiSuccess(supplierNameList
          .where((n) =>
              (productId == null || n.productId == productId) &&
              (supplierId == null || n.supplierId == supplierId))
          .toList());

  @override
  Future<ApiResult<int>> setSupplierName({
    required int supplierId,
    required int productId,
    required String supplierName,
    String? supplierCode,
    String? note,
    String? supplierJanCode,
    String? supplierMaker,
  }) async {
    lastSupplierName =
        (supplierId: supplierId, productId: productId, name: supplierName, code: supplierCode);
    lastSupplierNameExtra = (jan: supplierJanCode, maker: supplierMaker);
    return const ApiSuccess(1);
  }

  @override
  Future<ApiResult<bool>> removeSupplierName(int id) async {
    removedSupplierNameIds.add(id);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<Product>>> list(
      {String? search, String? status = 'active'}) async {
    return ApiSuccess(_products.where((p) {
      final statusOk = status == null || p.status == status;
      final searchOk = search == null ||
          search.isEmpty ||
          p.name.contains(search) ||
          p.janCode.contains(search) ||
          (p.sku?.contains(search) ?? false);
      return statusOk && searchOk;
    }).toList());
  }

  @override
  Future<ApiResult<int>> create({
    required String janCode,
    required String name,
    required String maker,
    String? category,
    double? price,
  }) async {
    if (failCreateWith != null) {
      return ApiFailure(message: failCreateWith!, statusCode: 400);
    }
    final id = _products.length + 1;
    _products = [
      ..._products,
      Product(id: id, janCode: janCode, name: name, maker: maker, category: category, price: price),
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
  String? lastMaker;
  ({String? jan, String? maker})? lastSupplierNameExtra;

  /// When set, setIdentity() fails with this message — the real RPC refuses a
  /// tracking mode that contradicts lots or serials already recorded (§37-15).
  String? failIdentityWith;

  @override
  Future<ApiResult<bool>> setIdentity({
    required int id,
    String? sku,
    TrackingMode? trackingMode,
    String? maker,
  }) async {
    lastIdentity = (id: id, sku: sku, trackingMode: trackingMode);
    lastMaker = maker;
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

  /// English names setNameEn() was asked to save (0117).
  final setNamesEn = <({int productId, String? nameEn})>[];

  @override
  Future<ApiResult<bool>> setNameEn(int productId, String? nameEn) async {
    setNamesEn.add((productId: productId, nameEn: nameEn));
    return const ApiSuccess(true);
  }

  /// Products delete() was asked to remove (0119), and the ids it refuses
  /// as in use.
  final deleted = <int>[];
  final inUse = <int>{};

  @override
  Future<ApiResult<bool>> delete(int id) async {
    if (inUse.contains(id)) return const ApiFailure(message: 'product is in use; deactivate it instead');
    deleted.add(id);
    _products = [for (final p in _products) if (p.id != id) p];
    return const ApiSuccess(true);
  }

  /// What importLines() was given (0130); lines whose JAN is already a
  /// product's become alerts.
  final importedLines = <List<Map<String, dynamic>>>[];
  List<ProductAlert> alertList = [];
  final deletedAlerts = <List<int>?>[];
  final addedOne = <Map<String, dynamic>>[];

  @override
  Future<ApiResult<LibraryImported>> importLines(List<Map<String, dynamic>> lines, {String? sourceFile}) async {
    importedLines.add(lines);
    final jans = {for (final p in _products) p.janCode};
    var created = 0;
    for (final l in lines) {
      final jan = '${l['jan_code'] ?? ''}';
      if (jan.isNotEmpty && jans.contains(jan)) {
        alertList = [
          ...alertList,
          ProductAlert(id: 900 + alertList.length, reason: ProductAlertReason.janExists, janCode: jan, name: '${l['product_name']}'),
        ];
      } else {
        created++;
        if (jan.isNotEmpty) jans.add(jan);
      }
    }
    return ApiSuccess(LibraryImported(created: created, alerts: lines.length - created));
  }

  @override
  Future<ApiResult<int>> addOne(Map<String, dynamic> fields) async {
    if (failCreateWith != null) return ApiFailure(message: failCreateWith!, statusCode: 400);
    final jan = '${fields['jan_code'] ?? ''}';
    final hit = _products.where((p) => jan.isNotEmpty && p.janCode == jan).firstOrNull;
    if (hit != null) return ApiFailure(message: 'jan_exists:${hit.id}:${hit.name}');
    addedOne.add(fields);
    final id = 800 + addedOne.length;
    _products = [
      ..._products,
      Product(
        id: id,
        janCode: jan,
        name: '${fields['name'] ?? fields['sku'] ?? (jan.isEmpty ? '名称未設定' : jan)}',
        maker: fields['maker'] as String?,
        category: fields['category'] as String?,
        price: (fields['price'] as num?)?.toDouble(),
      ),
    ];
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<List<ProductAlert>>> alerts() async => ApiSuccess(List.of(alertList));

  @override
  Future<ApiResult<int>> deleteAlerts(List<int>? ids) async {
    deletedAlerts.add(ids);
    final before = alertList.length;
    alertList = ids == null ? [] : [for (final a in alertList) if (!ids.contains(a.id)) a];
    return ApiSuccess(before - alertList.length);
  }

  /// What deleteMany() was asked (0126).
  final deleteManyCalls = <List<int>>[];

  @override
  Future<ApiResult<({List<int> removed, List<int> inUse})>> deleteMany(List<int> ids) async {
    deleteManyCalls.add(ids);
    final removed = [for (final id in ids) if (!inUse.contains(id)) id];
    deleted.addAll(removed);
    _products = [for (final p in _products) if (!removed.contains(p.id)) p];
    return ApiSuccess((removed: removed, inUse: [for (final id in ids) if (inUse.contains(id)) id]));
  }

  /// What reactivate() was asked (0123); [mayLift] says whether archived and
  /// discontinued ones may come back (product.lifecycle), dormant ones always.
  final reactivateCalls = <List<int>>[];
  bool mayLift = true;

  @override
  Future<ApiResult<({int changed, List<int> skipped})>> reactivate(List<int> ids) async {
    reactivateCalls.add(ids);
    final skipped = <int>[];
    var changed = 0;
    _products = [
      for (final p in _products)
        if (ids.contains(p.id) && p.lifecycle != ProductLifecycle.active)
          (p.lifecycle == ProductLifecycle.dormant || mayLift)
              ? (() {
                  changed++;
                  return p.withLifecycle(ProductLifecycle.active);
                })()
              : (() {
                  skipped.add(p.id);
                  return p;
                })()
        else
          p,
    ];
    return ApiSuccess((changed: changed, skipped: skipped));
  }

  /// What setLifecycle() was asked (0120).
  final lifecycleCalls = <({List<int> ids, ProductLifecycle lifecycle, String? reason})>[];

  @override
  Future<ApiResult<int>> setLifecycle(List<int> ids, ProductLifecycle lifecycle, {String? reason}) async {
    lifecycleCalls.add((ids: ids, lifecycle: lifecycle, reason: reason));
    var n = 0;
    _products = [
      for (final p in _products)
        if (ids.contains(p.id) && p.lifecycle != lifecycle) (() {
          n++;
          return p.withLifecycle(lifecycle, reason: reason);
        })() else p,
    ];
    return ApiSuccess(n);
  }

  /// Names setName() was asked to save (0118).
  final setNames = <({int productId, String lang, String? name})>[];

  @override
  Future<ApiResult<Map<String, String>>> setName(int productId, String lang, String? name) async {
    setNames.add((productId: productId, lang: lang, name: name));
    return ApiSuccess(name == null ? const <String, String>{} : {lang: name});
  }

  /// What setPack() and setWeight() were asked to save (0115).
  final setPacks = <({int productId, String uomCode, double factor, double? packageWeightG, double? grossWeightG})>[];
  final setWeights = <({int productId, double? unitWeightG, String source, String? url, String? note})>[];

  @override
  Future<ApiResult<bool>> setPack({
    required int productId,
    required String uomCode,
    required double conversionFactor,
    double? packageWeightG,
    double? grossWeightG,
  }) async {
    setPacks.add((productId: productId, uomCode: uomCode, factor: conversionFactor,
        packageWeightG: packageWeightG, grossWeightG: grossWeightG));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> setWeight({
    required int productId,
    double? unitWeightG,
    String source = 'manual',
    String? url,
    String? note,
  }) async {
    setWeights.add((productId: productId, unitWeightG: unitWeightG, source: source, url: url, note: note));
    return const ApiSuccess(true);
  }

  /// What setSize() was asked to save (0125).
  final setSizes = <({int productId, double? width, double? depth, double? height, String? note, String source})>[];

  @override
  Future<ApiResult<bool>> setSize({
    required int productId,
    double? widthMm,
    double? depthMm,
    double? heightMm,
    String? note,
    String source = 'manual',
  }) async {
    setSizes.add((productId: productId, width: widthMm, depth: depthMm, height: heightMm, note: note, source: source));
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

  /// What unlinkedJanCodes() would return.
  List<UnlinkedJan> unlinkedJans = const [];

  /// What productIdCoverage() would return.
  ProductIdCoverage coverage = const ProductIdCoverage(readyToSwitch: true);

  @override
  Future<ApiResult<List<UnlinkedJan>>> unlinkedJanCodes({int limit = 200}) async =>
      ApiSuccess(unlinkedJans);

  @override
  Future<ApiResult<ProductIdCoverage>> productIdCoverage() async =>
      ApiSuccess(coverage);
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

  /// What createDeliveryPlan() reports; a test overrides deliveryPlanId to
  /// assert on the id it navigates to.
  DeliveryPlanFromPurchaseOrderResult deliveryPlanResult =
      const DeliveryPlanFromPurchaseOrderResult(deliveryPlanId: 900, lines: 1);
  int? lastDeliveryPlanCreatedFor;

  PurchaseOrder _copyWith(
    PurchaseOrder o, {
    PurchaseOrderStatus? status,
    int? deliveryPlanId,
  }) =>
      PurchaseOrder(
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
        deliveryPlanId: deliveryPlanId ?? o.deliveryPlanId,
        deliveryPlans: o.deliveryPlans,
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

  @override
  Future<ApiResult<DeliveryPlanFromPurchaseOrderResult>> createDeliveryPlan(
    int id, {
    String? note,
  }) async {
    lastDeliveryPlanCreatedFor = id;
    final order = _orders.firstWhere((o) => o.id == id);
    if (order.status != PurchaseOrderStatus.approved) {
      return ApiFailure(
          message: 'purchase order is ${order.status.wire}', statusCode: 400);
    }
    // Like the RPC (0084), a plan takes everything still unplanned.
    _orders = [
      for (final o in _orders)
        if (o.id == id)
          PurchaseOrder(
            id: o.id,
            status: o.status,
            poNumber: o.poNumber,
            supplierId: o.supplierId,
            supplierName: o.supplierName,
            warehouseId: o.warehouseId,
            warehouseName: o.warehouseName,
            lines: [
              for (final l in o.lines)
                PurchaseOrderLine(
                  id: l.id,
                  janCode: l.janCode,
                  productName: l.productName,
                  quantity: l.quantity,
                  unitPrice: l.unitPrice,
                  planned: l.quantity,
                  received: l.received,
                  demands: l.demands,
                ),
            ],
            deliveryPlanId: deliveryPlanResult.deliveryPlanId,
            deliveryPlans: [
              ...o.deliveryPlans,
              PurchaseOrderDeliveryPlan(
                  id: deliveryPlanResult.deliveryPlanId, status: 'open'),
            ],
          )
        else
          o,
    ];
    return ApiSuccess(deliveryPlanResult);
  }

  ({int purchaseOrderId, int deliveryPlanId})? lastLink;

  List<PurchaseLinkCandidate> linkCandidateList = const [];
  PurchaseLinkResult linkResult = const PurchaseLinkResult(linkedUnits: 0);
  ({int lineId, List<({int salesOrderLineId, int quantity})> demands})? lastSetDemands;

  @override
  Future<ApiResult<List<PurchaseLinkCandidate>>> linkCandidates(
          int purchaseOrderLineId) async =>
      ApiSuccess(linkCandidateList);

  @override
  Future<ApiResult<PurchaseLinkResult>> setLineDemands(int purchaseOrderLineId,
      List<({int salesOrderLineId, int quantity})> demands) async {
    lastSetDemands = (lineId: purchaseOrderLineId, demands: demands);
    return ApiSuccess(linkResult);
  }

  @override
  Future<ApiResult<bool>> linkDeliveryPlan(
      int purchaseOrderId, int deliveryPlanId) async {
    lastLink = (purchaseOrderId: purchaseOrderId, deliveryPlanId: deliveryPlanId);
    return const ApiSuccess(true);
  }
}

/// Warehouse country/role stub (0087). [roles] is what `warehouse_roles`
/// returns; [lastSet] records what a save asked for.
class FakeWarehouseRoleRepository implements WarehouseRoleRepository {
  FakeWarehouseRoleRepository([this.roles = const []]);

  List<WarehouseRole> roles;
  ({int id, String country, bool receives})? lastSet;

  @override
  Future<ApiResult<List<WarehouseRole>>> list() async => ApiSuccess(roles);

  @override
  Future<ApiResult<bool>> set(int warehouseId,
      {required String countryCode, required bool receivesCrossBorder}) async {
    lastSet = (id: warehouseId, country: countryCode, receives: receivesCrossBorder);
    roles = [
      for (final r in roles)
        if (r.id == warehouseId)
          WarehouseRole(
              id: r.id,
              code: r.code,
              name: r.name,
              countryCode: countryCode,
              receivesCrossBorder: receivesCrossBorder,
              inspectionMode: r.inspectionMode,
              samplePercent: r.samplePercent,
              sampleMin: r.sampleMin)
        else
          r,
    ];
    return const ApiSuccess(true);
  }

  ({int id, WarehouseInspectionMode mode, int? percent, int? min})? lastInspection;

  @override
  Future<ApiResult<bool>> setInspection(int warehouseId,
      {required WarehouseInspectionMode mode, int? samplePercent, int? sampleMin}) async {
    lastInspection = (id: warehouseId, mode: mode, percent: samplePercent, min: sampleMin);
    roles = [
      for (final r in roles)
        if (r.id == warehouseId)
          WarehouseRole(
              id: r.id,
              code: r.code,
              name: r.name,
              countryCode: r.countryCode,
              receivesCrossBorder: r.receivesCrossBorder,
              inspectionMode: mode,
              samplePercent: samplePercent ?? r.samplePercent,
              sampleMin: sampleMin ?? r.sampleMin)
        else
          r,
    ];
    return const ApiSuccess(true);
  }
}

/// Virtual stock abroad stub (0088). [summaryResult] is what every summary
/// returns; [recorded] and [lastSummaryKey] record what the screen asked for.
class FakeVirtualStockRepository implements VirtualStockRepository {
  FakeVirtualStockRepository({
    this.warehouseList = const [],
    this.summaryResult = const VirtualStockSummary(totals: VirtualFigures()),
    this.historyList = const [],
  });

  List<VirtualWarehouse> warehouseList;
  VirtualStockSummary summaryResult;
  List<VirtualStockEntry> historyList;
  ({int warehouseId, DateTime from, DateTime to})? lastSummaryKey;
  final List<({int warehouseId, String jan, VirtualEntryType type, int quantity, String? note})>
      recorded = [];
  final List<int> deleted = [];

  @override
  Future<ApiResult<List<VirtualWarehouse>>> warehouses() async => ApiSuccess(warehouseList);

  @override
  Future<ApiResult<VirtualStockSummary>> summary(int warehouseId,
      {required DateTime from, required DateTime to}) async {
    lastSummaryKey = (warehouseId: warehouseId, from: from, to: to);
    return ApiSuccess(summaryResult);
  }

  @override
  Future<ApiResult<List<VirtualStockEntry>>> history(int warehouseId, int productId) async =>
      ApiSuccess(historyList);

  @override
  Future<ApiResult<int>> record({
    required int warehouseId,
    required String janCode,
    required VirtualEntryType type,
    required int quantity,
    DateTime? occurredOn,
    String? note,
  }) async {
    recorded.add((warehouseId: warehouseId, jan: janCode, type: type, quantity: quantity, note: note));
    return const ApiSuccess(1);
  }

  @override
  Future<ApiResult<bool>> delete(int entryId) async {
    deleted.add(entryId);
    return const ApiSuccess(true);
  }
}

/// Dashboard chart stub (0089).
class FakeDashboardChartsRepository implements DashboardChartsRepository {
  FakeDashboardChartsRepository({
    this.chart = const StockChartData(),
    this.orders = const [],
  });

  StockChartData chart;
  List<RecentPurchaseOrder> orders;

  String? lastCountry;

  @override
  Future<ApiResult<StockChartData>> stockChart({int limit = 10, String? countryCode}) async {
    lastCountry = countryCode;
    return ApiSuccess(chart);
  }

  @override
  Future<ApiResult<List<RecentPurchaseOrder>>> recentPurchaseOrders({int limit = 8}) async =>
      ApiSuccess(orders);
}

/// Order-first demand stub (0084): [items] is what `open_demand` returns;
/// [fills] and [purchases] record what the screen asked for.
class FakeDemandRepository implements DemandRepository {
  FakeDemandRepository({this.items = const []});

  List<OpenDemandItem> items;
  BackorderFillResult fillResult = const BackorderFillResult(reservedUnits: 0);
  PurchaseFromDemandResult purchaseResult =
      const PurchaseFromDemandResult(purchaseOrderId: 900, lines: 1, links: 1);
  final List<({int warehouseId, int? productId, int? lineId, int? quantity})> fills = [];
  final List<({String supplierName, int? supplierId, List<DemandPurchaseLine> lines})>
      purchases = [];

  @override
  Future<ApiResult<List<OpenDemandItem>>> openDemand({int? warehouseId}) async =>
      ApiSuccess(items);

  @override
  Future<ApiResult<BackorderFillResult>> fillBackorders({
    required int warehouseId,
    int? productId,
    int? salesOrderLineId,
    int? quantity,
  }) async {
    fills.add((
      warehouseId: warehouseId,
      productId: productId,
      lineId: salesOrderLineId,
      quantity: quantity,
    ));
    return ApiSuccess(fillResult);
  }

  @override
  Future<ApiResult<PurchaseFromDemandResult>> createPurchaseOrder({
    required String supplierName,
    required int warehouseId,
    required List<DemandPurchaseLine> lines,
    int? supplierId,
    DateTime? expectedDate,
    String? note,
  }) async {
    purchases.add((supplierName: supplierName, supplierId: supplierId, lines: lines));
    return ApiSuccess(purchaseResult);
  }
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
    int? openShipmentPlanId,
    List<SalesOrderShipment>? shipments,
    List<SalesOrderLine>? lines,
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
        lines: lines ?? o.lines,
        lineCount: o.lineCount,
        totalAmount: o.totalAmount,
        shipmentPlanId: shipmentPlanId ?? o.shipmentPlanId,
        openShipmentPlanId: openShipmentPlanId ?? o.openShipmentPlanId,
        shipments: shipments ?? o.shipments,
        reservations: o.reservations,
      );

  /// Approval reserves what [approvalResult] says it could and leaves the
  /// rest as backorder, the way approve_sales_order does since 0084.
  List<SalesOrderLine> _reserved(List<SalesOrderLine> lines) => [
        for (final l in lines)
          () {
            final skip = approvalResult.skipped.where((s) => s.lineId == l.id);
            final back = skip.isEmpty
                ? 0
                : (skip.first.backordered > 0 ? skip.first.backordered : l.quantity);
            return SalesOrderLine(
              id: l.id,
              janCode: l.janCode,
              productName: l.productName,
              quantity: l.quantity,
              unitPrice: l.unitPrice,
              productId: l.productId ?? l.id,
              promised: l.quantity - back,
              backordered: back,
            );
          }(),
      ];

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
    _orders = [
      for (final o in _orders)
        if (o.id == id && o.status == SalesOrderStatus.approved)
          _copyWith(o, lines: _reserved(o.lines))
        else
          o,
    ];
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
          _copyWith(
            o,
            shipmentPlanId: shipmentResult.shipmentPlanId,
            openShipmentPlanId: shipmentResult.shipmentPlanId,
            shipments: [
              ...o.shipments,
              SalesOrderShipment(id: shipmentResult.shipmentPlanId, status: 'open'),
            ],
          )
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

  ({int id, String country})? lastCountry;

  @override
  Future<ApiResult<bool>> setCountry(int id, String countryCode) async {
    lastCountry = (id: id, country: countryCode);
    return const ApiSuccess(true);
  }

  // Our codes for companies (0112), in memory.
  List<PartnerCodeFormat> formats = const [
    PartnerCodeFormat(kind: PartnerKind.supplier, prefix: 'S', digits: 5, nextNumber: 1, nextCode: 'S00001'),
    PartnerCodeFormat(kind: PartnerKind.customer, prefix: 'C', digits: 5, nextNumber: 1, nextCode: 'C00001'),
    PartnerCodeFormat(kind: PartnerKind.both, prefix: 'B', digits: 5, nextNumber: 1, nextCode: 'B00001'),
  ];
  ({int id, String? code, String? theirCodeForUs})? lastCodes;
  final List<(PartnerKind, String, int, int?)> savedFormats = [];
  int issued = 0;
  Map<int, List<PartnerVendorCode>> vendors = {};

  @override
  Future<ApiResult<bool>> setCodes(int id, {String? code, String? theirCodeForUs}) async {
    lastCodes = (id: id, code: code, theirCodeForUs: theirCodeForUs);
    _partners = [
      for (final p in _partners)
        if (p.id == id)
          TradingPartner(
            id: p.id,
            name: p.name,
            kind: p.kind,
            code: (code ?? '').isEmpty ? p.code : code,
            status: p.status,
            theirCodeForUs: (theirCodeForUs ?? '').isEmpty ? null : theirCodeForUs,
            vendorCodes: p.vendorCodes,
          )
        else
          p,
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<PartnerCodeFormat>>> codeFormats() async => ApiSuccess(formats);

  @override
  Future<ApiResult<List<PartnerCodeFormat>>> saveCodeFormat(PartnerKind kind,
      {required String prefix, required int digits, int? nextNumber}) async {
    savedFormats.add((kind, prefix, digits, nextNumber));
    formats = [
      for (final f in formats)
        if (f.kind == kind)
          PartnerCodeFormat(
            kind: kind,
            prefix: prefix,
            digits: digits,
            nextNumber: nextNumber ?? f.nextNumber,
            nextCode: '$prefix${'${nextNumber ?? f.nextNumber}'.padLeft(digits, '0')}',
          )
        else
          f,
    ];
    return ApiSuccess(formats);
  }

  @override
  Future<ApiResult<int>> issueMissingCodes() async => ApiSuccess(issued);

  @override
  Future<ApiResult<List<PartnerVendorCode>>> vendorCodes(int partnerId) async => ApiSuccess(vendors[partnerId] ?? const []);

  ({int id, String notes})? lastNotes;

  @override
  Future<ApiResult<String?>> setReadingNotes(int id, String notes) async {
    lastNotes = (id: id, notes: notes);
    _partners = [
      for (final p in _partners)
        if (p.id == id)
          TradingPartner(
            id: p.id,
            name: p.name,
            kind: p.kind,
            code: p.code,
            status: p.status,
            theirCodeForUs: p.theirCodeForUs,
            vendorCodes: p.vendorCodes,
            readingNotes: notes.trim().isEmpty ? null : notes.trim(),
          )
        else
          p,
    ];
    return ApiSuccess(notes.trim().isEmpty ? null : notes.trim());
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
    this.discrepancies = const [],
  });

  List<ExpiringLot> lots;
  List<Reservation> reservationList;
  List<OverAllocatedStock> overAllocatedList;
  List<ReplenishmentSuggestion> suggestions;
  List<StockDiscrepancy> discrepancies;

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

  /// What fulfilReservation() was last asked for.
  ({int id, int? quantity})? lastFulfil;
  String? failFulfilWith;

  @override
  Future<ApiResult<bool>> fulfilReservation(int reservationId,
      {int? quantity}) async {
    lastFulfil = (id: reservationId, quantity: quantity);
    if (failFulfilWith != null) {
      return ApiFailure(message: failFulfilWith!, statusCode: 400);
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
            status: r.status,
            fulfilledQuantity:
                r.fulfilledQuantity + (quantity ?? r.outstanding),
            allocatedQuantity: r.allocatedQuantity,
            referenceType: r.referenceType,
            referenceId: r.referenceId,
            expiresAt: r.expiresAt,
            isExpired: r.isExpired,
          )
        else
          r,
    ];
    return const ApiSuccess(true);
  }

  AllocationOutcome allocationOutcome = const AllocationOutcome(allocated: 0, short: 0);
  ({int id, int? quantity})? lastAllocate;
  final List<int> releasedAllocationIds = [];
  ({int productId, int warehouseId, int quantity, String? note})? lastReserve;

  @override
  Future<ApiResult<AllocationOutcome>> allocateStock(int reservationId,
      {int? quantity}) async {
    lastAllocate = (id: reservationId, quantity: quantity);
    return ApiSuccess(allocationOutcome);
  }

  @override
  Future<ApiResult<bool>> releaseAllocation(int allocationId) async {
    releasedAllocationIds.add(allocationId);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<int>> reserveStock({
    required int productId,
    required int warehouseId,
    required int quantity,
    DateTime? expiresAt,
    String? note,
  }) async {
    lastReserve = (
      productId: productId,
      warehouseId: warehouseId,
      quantity: quantity,
      note: note,
    );
    return const ApiSuccess(1);
  }

  @override
  Future<ApiResult<List<ReplenishmentSuggestion>>> replenishment({
    int? warehouseId,
  }) async =>
      ApiSuccess(suggestions);

  @override
  Future<ApiResult<List<StockDiscrepancy>>> stockReconciliation({
    int? warehouseId,
  }) async =>
      ApiSuccess(discrepancies);
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
    this.types = const [],
    ExceptionSummary? summaryValue,
  }) : summaryValue = summaryValue ??
            ExceptionSummary(
              open: exceptions.where((e) => e.isOpen).length,
              blockers: exceptions.where((e) => e.isOpen && e.isBlocker).length,
            );

  List<WarehouseException> exceptions;
  List<ExceptionType> types;
  ExceptionSummary summaryValue;

  String? lastCategory;
  bool? lastIncludeClosed;
  int? lastWarehouseId;
  int? acknowledgedId;
  ({int id, ExceptionResolution resolution, String? note})? lastResolution;
  ({int id, String? reason})? lastCancel;
  String? failResolveWith;

  /// What raise() was last asked for.
  ({
    String exceptionType,
    int warehouseId,
    String? note,
    String? janCode,
    int? quantity,
  })? lastRaised;
  String? failRaiseWith;

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
  Future<ApiResult<List<ExceptionType>>> listTypes() async => ApiSuccess(types);

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
  }) async {
    lastRaised = (
      exceptionType: exceptionType,
      warehouseId: warehouseId,
      note: note,
      janCode: janCode,
      quantity: quantity,
    );
    if (failRaiseWith != null) {
      return ApiFailure(message: failRaiseWith!, statusCode: 403);
    }
    return const ApiSuccess(1);
  }
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

class FakeRoleDashboardRepository implements RoleDashboardRepository {
  FakeRoleDashboardRepository({
    this.schedule = const InboundSchedule(),
    this.stock = const StockOverview(),
    this.sales = const SalesCycle(),
  });

  InboundSchedule schedule;
  StockOverview stock;
  SalesCycle sales;
  String? lastStockCountry;
  String? lastStockSearch;
  String? lastSalesCountry = 'unset';
  ({int warehouseId, List<({String janCode, int quantity})> lines, String? supplierName, DateTime? expectedOn})?
      lastManual;

  @override
  Future<ApiResult<InboundSchedule>> inboundSchedule({int? warehouseId}) async =>
      ApiSuccess(schedule);

  @override
  Future<ApiResult<StockOverview>> stockOverview({String? countryCode, String? search}) async {
    lastStockCountry = countryCode;
    lastStockSearch = search;
    return ApiSuccess(stock);
  }

  @override
  Future<ApiResult<SalesCycle>> salesCycle({String? countryCode = 'CN', int months = 12}) async {
    lastSalesCountry = countryCode;
    return ApiSuccess(sales);
  }

  @override
  Future<ApiResult<String>> createManualInboundList({
    required int warehouseId,
    required List<({String janCode, int quantity})> lines,
    String? supplierName,
    DateTime? expectedOn,
  }) async {
    lastManual = (
      warehouseId: warehouseId,
      lines: lines,
      supplierName: supplierName,
      expectedOn: expectedOn,
    );
    return const ApiSuccess('MN-000001');
  }
}


/// The notation dictionary and training runs (0105/0106), in memory.
class FakeNotationRepository implements NotationRepository {
  FakeNotationRepository({
    this.read = const TrainingRead(),
    List<TrainingRun> runs = const [],
    List<PartnerTrainingStats> stats = const [],
    List<NotationDialect> dialectRows = const [],
    List<ColumnAlias> aliases = const [],
  })  : runs = List.of(runs),
        statsRows = List.of(stats),
        dialectRows = List.of(dialectRows),
        aliases = List.of(aliases);

  /// What readSample() returns.
  TrainingRead read;
  List<TrainingRun> runs;
  List<PartnerTrainingStats> statsRows;
  List<NotationDialect> dialectRows;
  List<ColumnAlias> aliases;

  ({int partnerId, Map<int, ColumnChoice> overrides, String fileName, Map<int, String> headers})? lastRead;
  ({int partnerId, int? trainingId, List<ReadLineResult> lines, List<ReadColumn> columns})? lastLearn;
  final List<int> discarded = [];
  final List<({int id, int? productId, bool confirmed})> confirmed = [];
  final List<int> removedDialects = [];
  ({int? partnerId, String header, ColumnField field})? lastAlias;
  ({int? partnerId, String? field, String? search, bool unconfirmedOnly})? lastDialectQuery;

  @override
  Future<ApiResult<TrainingRead>> readSample({
    required int partnerId,
    required MultipartFile file,
    Map<int, ColumnChoice> overrides = const {},
    Map<int, String> columnHeaders = const {},
  }) async {
    lastRead = (
      partnerId: partnerId,
      overrides: Map.of(overrides),
      fileName: file.filename ?? '',
      headers: Map.of(columnHeaders),
    );
    return ApiSuccess(read);
  }

  @override
  Future<ApiResult<LearnResult>> learn({
    required int partnerId,
    int? trainingId,
    required List<ReadLineResult> lines,
    required List<ReadColumn> columns,
  }) async {
    lastLearn = (partnerId: partnerId, trainingId: trainingId, lines: lines, columns: columns);
    final n = lines.where((l) => l.resolved).length;
    return ApiSuccess(LearnResult(learned: n, added: n));
  }

  @override
  Future<ApiResult<List<TrainingRun>>> trainings({int? partnerId}) async => ApiSuccess(runs);

  @override
  Future<ApiResult<List<PartnerTrainingStats>>> stats() async => ApiSuccess(statsRows);

  @override
  Future<ApiResult<bool>> discard(int trainingId) async {
    discarded.add(trainingId);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<NotationDialect>>> dialects({
    int? partnerId,
    String? field,
    String? search,
    bool unconfirmedOnly = false,
  }) async {
    lastDialectQuery =
        (partnerId: partnerId, field: field, search: search, unconfirmedOnly: unconfirmedOnly);
    return ApiSuccess(dialectRows
        .where((d) =>
            (field == null || d.field == field) &&
            (!unconfirmedOnly || !d.confirmed) &&
            (partnerId == null || d.partnerId == partnerId))
        .toList());
  }

  @override
  Future<ApiResult<bool>> confirmDialect(int id,
      {int? productId, int? makerId, bool confirmed = true}) async {
    this.confirmed.add((id: id, productId: productId, confirmed: confirmed));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> removeDialect(int id) async {
    removedDialects.add(id);
    dialectRows = dialectRows.where((d) => d.id != id).toList();
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<ColumnAlias>>> columnAliases({int? partnerId}) async =>
      ApiSuccess(aliases);

  @override
  Future<ApiResult<bool>> setColumnAlias(
      {int? partnerId, required String header, required ColumnField field}) async {
    lastAlias = (partnerId: partnerId, header: header, field: field);
    aliases = [...aliases, ColumnAlias(id: 900 + aliases.length, header: header, field: field, partnerId: partnerId, source: 'manual')];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> removeColumnAlias(int id) async {
    aliases = aliases.where((a) => a.id != id).toList();
    return const ApiSuccess(true);
  }

  List<LibraryVersion> versions = [];
  int? lastSnapshotPartner;
  int? lastRestored;

  @override
  Future<ApiResult<List<LibraryVersion>>> libraryVersions(int partnerId) async => ApiSuccess(versions);

  @override
  Future<ApiResult<int>> snapshotLibrary(int partnerId, {String? note}) async {
    lastSnapshotPartner = partnerId;
    final v = LibraryVersion(id: 100 + versions.length, version: versions.length + 1, note: note, dialectCount: 3);
    versions = [v, ...versions];
    return ApiSuccess(v.id);
  }

  @override
  Future<ApiResult<LibraryRestoreResult>> restoreLibrary(int versionId) async {
    lastRestored = versionId;
    return const ApiSuccess(LibraryRestoreResult(dialects: 2, aliases: 1));
  }

  // The field library (0112), in memory.
  FieldLibrary library = const FieldLibrary(fields: [
    DocumentField(key: 'jan', description: 'JANコード', headings: [
      FieldHeading(id: 1, header: 'JANコード', source: 'seed'),
      FieldHeading(id: 2, header: 'ジャパンコード', source: 'seed'),
      FieldHeading(id: 3, header: 'Jan', partnerId: 1, partnerName: 'A商社', source: 'import'),
    ]),
    DocumentField(key: 'maker', headings: [FieldHeading(id: 4, header: 'メーカー', source: 'seed')]),
  ], attributes: [
    AttributeHeadings(id: 1, key: 'color', name: '色', headings: [FieldHeading(id: 5, header: 'カラー', source: 'seed')]),
  ]);
  Map<String, Map<String, String>> labels = {};
  ({String key, Map<String, String> labels})? lastLabels;
  ({int? partnerId, String header, ColumnChoice choice})? lastHeading;
  final List<int> removedAliases = [];

  @override
  Future<ApiResult<FieldLibrary>> fieldLibrary() async => ApiSuccess(library);

  @override
  Future<ApiResult<FieldLibrary>> saveFieldLabels(String key, Map<String, String> labels, {String? description}) async {
    final clean = {for (final e in labels.entries) if (e.value.trim().isNotEmpty) e.key: e.value.trim()};
    lastLabels = (key: key, labels: clean);
    this.labels = {...this.labels, key: clean};
    library = FieldLibrary(fields: [
      for (final f in library.fields)
        f.key == key ? DocumentField(key: f.key, labels: clean, description: f.description, headings: f.headings) : f,
    ], attributes: library.attributes);
    return ApiSuccess(library);
  }

  @override
  Future<ApiResult<Map<String, Map<String, String>>>> fieldLabels() async => ApiSuccess(labels);

  @override
  Future<ApiResult<bool>> setHeading({int? partnerId, required String header, required ColumnChoice choice}) async {
    lastHeading = (partnerId: partnerId, header: header, choice: choice);
    return const ApiSuccess(true);
  }

  // Warning reports (0113), in memory.
  final List<({int? partnerId, String flag, bool right, Map<String, dynamic>? line, String? note})> reports = [];
  List<WarningStat> warningRows = const [];

  @override
  Future<ApiResult<bool>> reportWarning({
    int? partnerId,
    required String flag,
    required bool right,
    Map<String, dynamic>? line,
    String? note,
  }) async {
    reports.add((partnerId: partnerId, flag: flag, right: right, line: line, note: note));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<WarningStat>>> warningStats() async => ApiSuccess(warningRows);
}


/// The supply chain layer (0107), in memory: each read returns what the test
/// set, each call is recorded.
class FakeSupplyChainRepository implements SupplyChainRepository {
  FakeSupplyChainRepository({
    this.dashboardRun = const ScRun(),
    this.modelData = const ScModel(),
    this.comparison,
    this.productViewData = const ScProductView(),
    this.multi,
    this.checks = const [],
    this.stats = const [],
    List<ScScenario> scenarioRows = const [],
    this.resultRows = const [],
  }) : scenarioRows = List.of(scenarioRows);

  ScRun dashboardRun;
  ScModel modelData;
  ScComparison? comparison;
  ScProductView productViewData;
  ScMultiComparison? multi;
  List<ScPurchaseCheck> checks;
  List<ScSupplierStat> stats;
  List<ScScenario> scenarioRows;
  List<ScResultRow> resultRows;

  int dashboardCalls = 0;
  bool? lastSave;
  ScScenarioParams? lastRunParams;
  String? lastRunName;
  List<(String, ScScenarioParams)>? lastCompare;
  List<Map<String, dynamic>>? lastDisruptions;
  List<Map<String, dynamic>>? lastCheckLines;
  ({int productId, List<double> rates})? lastProduct;
  ScSupplyTerm? lastTerm;
  ({int productId, ScProfile profile})? lastProfile;
  ScCostRule? lastRule;
  ScTariffRule? lastTariff;
  (String, double)? lastFx;
  ScRiskEvent? lastEvent;
  Map<String, dynamic>? lastNode;
  ({String name, List<ScEdge> edges})? lastRoute;
  ({String name, ScScenarioParams params})? lastScenario;
  final List<(String, int)> archived = [];
  int seedCalls = 0;

  @override
  Future<ApiResult<ScRun>> dashboard({int? warehouseId, bool save = false}) async {
    dashboardCalls++;
    lastSave = save;
    return ApiSuccess(dashboardRun);
  }

  @override
  Future<ApiResult<ScComparison>> run({int? warehouseId, required ScScenarioParams params, String? name, int? scenarioId}) async {
    lastRunParams = params;
    lastRunName = name;
    return comparison == null ? const ApiFailure(message: 'no comparison') : ApiSuccess(comparison!);
  }

  @override
  Future<ApiResult<ScMultiComparison>> compare({int? warehouseId, required List<(String, ScScenarioParams)> scenarios}) async {
    lastCompare = scenarios;
    return multi == null ? const ApiFailure(message: 'no comparison') : ApiSuccess(multi!);
  }

  @override
  Future<ApiResult<ScProductView>> product({required int productId, int? warehouseId, List<double> rates = const [], ScScenarioParams? params}) async {
    lastProduct = (productId: productId, rates: rates);
    return ApiSuccess(productViewData);
  }

  @override
  Future<ApiResult<ScComparison>> disruption({int? warehouseId, required List<Map<String, dynamic>> disruptions, String? name}) async {
    lastDisruptions = disruptions;
    return comparison == null ? const ApiFailure(message: 'no comparison') : ApiSuccess(comparison!);
  }

  @override
  Future<ApiResult<List<ScPurchaseCheck>>> purchaseCheck({int? warehouseId, required List<Map<String, dynamic>> lines}) async {
    lastCheckLines = lines;
    return ApiSuccess(checks);
  }

  @override
  Future<ApiResult<ScModel>> model({int? warehouseId, List<int>? productIds}) async => ApiSuccess(modelData);

  @override
  Future<ApiResult<List<ScSupplierStat>>> supplierStats() async => ApiSuccess(stats);

  @override
  Future<ApiResult<Map<String, dynamic>>> seedFromHistory() async {
    seedCalls++;
    return const ApiSuccess({'from_purchase_orders': 2, 'from_documents': 1, 'nodes': 3});
  }

  @override
  Future<ApiResult<int>> saveNode(Map<String, dynamic> node) async {
    lastNode = node;
    return const ApiSuccess(1);
  }

  @override
  Future<ApiResult<int>> saveRoute({int? id, required String name, required List<ScEdge> edges, String? note}) async {
    lastRoute = (name: name, edges: edges);
    return const ApiSuccess(1);
  }

  @override
  Future<ApiResult<int>> saveTerm(ScSupplyTerm term) async {
    lastTerm = term;
    return const ApiSuccess(1);
  }

  @override
  Future<ApiResult<int>> saveProfile(int productId, ScProfile profile) async {
    lastProfile = (productId: productId, profile: profile);
    return ApiSuccess(productId);
  }

  @override
  Future<ApiResult<int>> saveCostRule(ScCostRule rule) async {
    lastRule = rule;
    return const ApiSuccess(1);
  }

  @override
  Future<ApiResult<int>> saveTariffRule(ScTariffRule rule) async {
    lastTariff = rule;
    return const ApiSuccess(1);
  }

  @override
  Future<ApiResult<bool>> saveFx(String currency, double rate) async {
    lastFx = (currency, rate);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<int>> saveRiskEvent(ScRiskEvent event) async {
    lastEvent = event;
    return const ApiSuccess(1);
  }

  @override
  Future<ApiResult<bool>> archive(String kind, int id) async {
    archived.add((kind, id));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<int>> saveScenario({int? id, required String name, String? description, int? warehouseId, required ScScenarioParams params}) async {
    lastScenario = (name: name, params: params);
    return ApiSuccess(id ?? 77);
  }

  @override
  Future<ApiResult<List<ScScenario>>> scenarios() async => ApiSuccess(scenarioRows);

  @override
  Future<ApiResult<List<ScResultRow>>> results({int limit = 50, String? kind}) async => ApiSuccess(resultRows);

  @override
  Future<ApiResult<Map<String, dynamic>>> result(int id) async => const ApiSuccess({});
}


/// Supplier invoices and the four-way match (0108), in memory.
class FakeDocumentsRepository implements DocumentsRepository {
  FakeDocumentsRepository({this.matchResult, this.exceptionRows = const [], List<SupplierInvoice>? invoiceRows})
      : invoiceRows = invoiceRows ?? [];

  DocumentMatch? matchResult;
  List<DocumentException> exceptionRows;
  final List<SupplierInvoice> invoiceRows;
  SupplierInvoice? lastSaved;
  final List<(int, InvoiceStatus)> statusCalls = [];
  (int, double, double)? lastTolerance;
  int termsUpdated = 2;

  @override
  Future<ApiResult<DocumentMatch>> match(int purchaseOrderId) async =>
      ApiSuccess(matchResult ?? DocumentMatch(purchaseOrderId: purchaseOrderId));

  @override
  Future<ApiResult<List<DocumentException>>> exceptions({int? warehouseId}) async => ApiSuccess(exceptionRows);

  @override
  Future<ApiResult<List<SupplierInvoice>>> invoices({int? purchaseOrderId}) async =>
      ApiSuccess([for (final i in invoiceRows) if (purchaseOrderId == null || i.purchaseOrderId == purchaseOrderId) i]);

  @override
  Future<ApiResult<SupplierInvoice>> invoice(int id) async {
    for (final i in invoiceRows) {
      if (i.id == id) return ApiSuccess(i);
    }
    return const ApiFailure(message: 'not found', statusCode: 404);
  }

  @override
  Future<ApiResult<InvoiceSaveResult>> save(SupplierInvoice invoice) async {
    lastSaved = invoice;
    return ApiSuccess(InvoiceSaveResult(id: invoice.id ?? 900, status: InvoiceStatus.mismatch, match: matchResult));
  }

  @override
  Future<ApiResult<int>> setStatus(int id, InvoiceStatus status, {String? note}) async {
    statusCalls.add((id, status));
    return ApiSuccess(status == InvoiceStatus.approved ? termsUpdated : 0);
  }

  @override
  Future<ApiResult<bool>> setTolerance(int partnerId, double qtyPct, double pricePct) async {
    lastTolerance = (partnerId, qtyPct, pricePct);
    return const ApiSuccess(true);
  }
}


/// The product library (0109), in memory. Pictures "upload" to fake paths
/// and sign to `https://img.test/<path>`.
class FakeProductImageRepository implements ProductImageRepository {
  FakeProductImageRepository({
    List<LibraryProduct>? products,
    Map<int, List<ProductImage>>? images,
    List<ProductAttributeDef>? attributeDefs,
    Map<int, ProductProfile>? profiles,
  })  : products = products ?? [],
        images = images ?? {},
        attributeDefs = attributeDefs ??
            [
              const ProductAttributeDef(id: 1, key: 'color', name: '色'),
              const ProductAttributeDef(id: 2, key: 'size', name: 'サイズ'),
            ],
        profiles = profiles ?? {};

  /// How each supplier calls each product (0110).
  final List<ProductAttributeDef> attributeDefs;
  final Map<int, ProductProfile> profiles;
  Map<int, String?>? lastAttributeValues;
  SupplierProfileDraft? lastDraft;
  (int, int)? lastRemoved;

  ProductProfile _profileOf(int productId) =>
      profiles[productId] ??
      ProductProfile(
        productId: productId,
        name: 'P$productId',
        attributes: [for (final a in attributeDefs) ProductAttributeValue(attribute: a)],
      );

  ProductProfile _with(ProductProfile p, {List<ProductAttributeValue>? attributes, List<SupplierProfile>? suppliers}) =>
      profiles[p.productId] = ProductProfile(
        productId: p.productId,
        name: p.name,
        janCode: p.janCode,
        sku: p.sku,
        maker: p.maker,
        attributes: attributes ?? p.attributes,
        suppliers: suppliers ?? p.suppliers,
      );

  @override
  Future<ApiResult<List<ProductAttributeDef>>> attributes() async => ApiSuccess(attributeDefs);

  @override
  Future<ApiResult<List<ProductAttributeDef>>> saveAttribute({int? id, required String name, String? unit, bool? active}) async {
    attributeDefs.add(ProductAttributeDef(id: 100 + attributeDefs.length, key: 'attr_${attributeDefs.length}', name: name, unit: unit));
    return ApiSuccess(attributeDefs);
  }

  @override
  Future<ApiResult<ProductProfile>> profile(int productId) async => ApiSuccess(_profileOf(productId));

  @override
  Future<ApiResult<ProductProfile>> setAttributeValues(int productId, Map<int, String?> values) async {
    lastAttributeValues = values;
    final p = _profileOf(productId);
    return ApiSuccess(_with(p, attributes: [
      for (final a in p.attributes)
        values.containsKey(a.attribute.id)
            ? ProductAttributeValue(attribute: a.attribute, value: (values[a.attribute.id] ?? '').isEmpty ? null : values[a.attribute.id])
            : a,
    ]));
  }

  @override
  Future<ApiResult<ProductProfile>> saveSupplierProfile(SupplierProfileDraft draft) async {
    lastDraft = draft;
    final p = _profileOf(draft.productId);
    final s = SupplierProfile(
      supplierId: draft.supplierId,
      supplierName: 'S${draft.supplierId}',
      name: draft.name,
      code: draft.code,
      janCode: draft.janCode,
      maker: draft.maker,
      attributes: [
        for (final a in draft.attributes)
          if ((a.rawValue ?? '').isNotEmpty)
            SupplierAttribute(
              attributeId: a.attributeId,
              key: attributeDefs.firstWhere((d) => d.id == a.attributeId).key,
              name: attributeDefs.firstWhere((d) => d.id == a.attributeId).name,
              rawName: a.rawName,
              rawValue: a.rawValue!,
            ),
      ],
    );
    return ApiSuccess(_with(p, suppliers: [
      for (final x in p.suppliers)
        if (x.supplierId != draft.supplierId) x,
      s,
    ]));
  }

  @override
  Future<ApiResult<ProductProfile>> removeSupplierProfile(int productId, int supplierId) async {
    lastRemoved = (productId, supplierId);
    final p = _profileOf(productId);
    return ApiSuccess(_with(p, suppliers: [for (final x in p.suppliers) if (x.supplierId != supplierId) x]));
  }

  final List<LibraryProduct> products;
  final Map<int, List<ProductImage>> images;
  int facesCalls = 0;
  final List<({List<int> ids, List<String> jans})> faceRequests = [];
  final List<(int, List<int>)> reorders = [];
  final List<int> withdrawn = [];
  ({int productId, String fileName, bool first})? lastUpload;
  ({String? query, bool withoutImages})? lastLibraryQuery;
  int _seq = 1000;

  List<ProductImage> _live(int productId) => [...(images[productId] ?? const <ProductImage>[])]..sort((a, b) => a.position.compareTo(b.position));

  List<ProductImage> _renumber(int productId, List<ProductImage> list) {
    final out = [
      for (var i = 0; i < list.length; i++)
        ProductImage(id: list[i].id, productId: productId, storagePath: list[i].storagePath, position: i + 1, caption: list[i].caption),
    ];
    images[productId] = out;
    return out;
  }

  @override
  Future<ApiResult<List<LibraryProduct>>> library({String? query, bool withoutImages = false, int limit = 60, int offset = 0}) async {
    lastLibraryQuery = (query: query, withoutImages: withoutImages);
    return ApiSuccess([
      for (final p in products)
        if ((query == null || p.name.contains(query) || (p.janCode ?? '').contains(query)) &&
            (!withoutImages || _live(p.id).isEmpty))
          LibraryProduct(
            id: p.id,
            name: p.name,
            janCode: p.janCode,
            maker: p.maker,
            facePath: _live(p.id).isEmpty ? null : _live(p.id).first.storagePath,
            imageCount: _live(p.id).length,
          ),
    ]);
  }

  @override
  Future<ApiResult<List<ProductImage>>> imagesOf(int productId) async => ApiSuccess(_live(productId));

  @override
  Future<ApiResult<List<ProductFace>>> faces({List<int> productIds = const [], List<String> jans = const []}) async {
    facesCalls++;
    faceRequests.add((ids: productIds, jans: jans));
    final out = <ProductFace>[];
    for (final p in products) {
      final live = _live(p.id);
      if (live.isEmpty) continue;
      if (productIds.contains(p.id) || jans.contains(normalizeJanKey(p.janCode))) {
        out.add(ProductFace(productId: p.id, janCode: p.janCode, storagePath: live.first.storagePath, count: live.length));
      }
    }
    return ApiSuccess(out);
  }

  @override
  Future<ApiResult<Map<String, String>>> signUrls(List<String> paths) async =>
      ApiSuccess({for (final p in paths) p: 'https://img.test/$p'});

  @override
  Future<ApiResult<List<ProductImage>>> upload(int productId,
      {required Uint8List bytes, required String fileName, required String contentType, bool first = false, String? caption}) async {
    lastUpload = (productId: productId, fileName: fileName, first: first);
    final img = ProductImage(id: _seq++, productId: productId, storagePath: '$productId/$fileName');
    final live = _live(productId);
    return ApiSuccess(_renumber(productId, first ? [img, ...live] : [...live, img]));
  }

  @override
  Future<ApiResult<List<ProductImage>>> reorder(int productId, List<int> ids) async {
    reorders.add((productId, ids));
    final live = _live(productId);
    final ordered = [
      for (final id in ids) ...live.where((i) => i.id == id),
      ...live.where((i) => !ids.contains(i.id)),
    ];
    return ApiSuccess(_renumber(productId, ordered));
  }

  @override
  Future<ApiResult<List<ProductImage>>> withdraw(int imageId) async {
    withdrawn.add(imageId);
    for (final e in images.entries) {
      if (e.value.any((i) => i.id == imageId)) {
        return ApiSuccess(_renumber(e.key, [for (final i in _live(e.key)) if (i.id != imageId) i]));
      }
    }
    return const ApiFailure(message: 'not found', statusCode: 404);
  }
}

/// Our product format (0111) in memory: formats, each product's naming parts,
/// makers, and proposals for a document's new lines.
class FakeProductNamingRepository implements ProductNamingRepository {
  FakeProductNamingRepository({
    List<NameFormat>? formats,
    Map<int, ProductNaming>? namings,
    List<MakerEntry>? makerList,
    List<ProductProposal>? proposals,
  })  : formatList = formats ??
            [
              const NameFormat(id: 1, name: '標準', template: '{base} {attr:size} {attr:color}', isDefault: true, products: 3),
              const NameFormat(id: 2, name: 'メーカー名つき', template: '{maker} {base} {attr:size} {attr:color}'),
            ],
        namings = namings ?? {},
        makerList = makerList ?? [const MakerEntry(id: 7, name: 'ミツビシ', products: 5, dialects: 1)],
        proposals = proposals ?? [];

  final List<NameFormat> formatList;
  final Map<int, ProductNaming> namings;
  final List<MakerEntry> makerList;
  final List<ProductProposal> proposals;

  ({int? id, String name, String template, bool? isDefault})? lastSaved;
  (int, ProductNamingDraft)? lastNaming;
  (int, String)? lastMakerRename;
  (int, String, String)? lastValueRename;
  List<Map<String, dynamic>>? lastProposeLines;
  int? lastProposePartner;
  List<ProductProposal>? lastRegistered;
  int? lastRegisterFormat;
  String? lastPreviewTemplate;

  @override
  Future<ApiResult<List<NameFormat>>> formats() async => ApiSuccess([...formatList]);

  @override
  Future<ApiResult<List<NamePreview>>> preview(String template, {int? formatId, int limit = 20}) async {
    lastPreviewTemplate = template;
    return ApiSuccess([
      NamePreview(
        productId: 1,
        current: 'ユニボール エア 0.5mm 赤',
        next: renderProductName(template, base: 'ユニボール エア', maker: '三菱鉛筆', attributes: const {'size': '0.5mm', 'color': '赤'}),
      ),
    ]);
  }

  @override
  Future<ApiResult<NameFormatSaved>> saveFormat({int? id, required String name, required String template, bool? isDefault, bool? active}) async {
    lastSaved = (id: id, name: name, template: template, isDefault: isDefault);
    final newId = id ?? 100 + formatList.length;
    formatList.removeWhere((f) => f.id == newId);
    formatList.add(NameFormat(id: newId, name: name, template: template, isDefault: isDefault ?? false));
    return ApiSuccess(NameFormatSaved(id: newId, renamed: 3, formats: [...formatList]));
  }

  @override
  Future<ApiResult<ProductNaming>> naming(int productId) async =>
      ApiSuccess(namings[productId] ?? ProductNaming(id: productId, name: 'P$productId'));

  @override
  Future<ApiResult<ProductNaming>> setNaming(int productId, ProductNamingDraft draft) async {
    lastNaming = (productId, draft);
    final n = ProductNaming(
      id: productId,
      name: draft.manual ? (draft.name ?? '') : (draft.baseName ?? ''),
      baseName: draft.baseName,
      unit: draft.unit,
      listPrice: draft.listPrice,
      formatId: draft.formatId,
      manual: draft.manual,
    );
    namings[productId] = n;
    return ApiSuccess(n);
  }

  @override
  Future<ApiResult<List<MakerEntry>>> makers({String? search}) async =>
      ApiSuccess([for (final m in makerList) if (search == null || m.name.contains(search)) m]);

  @override
  Future<ApiResult<int>> renameMaker(int makerId, String name) async {
    lastMakerRename = (makerId, name);
    final i = makerList.indexWhere((m) => m.id == makerId);
    final m = makerList[i];
    makerList[i] = MakerEntry(id: m.id, name: name, products: m.products, dialects: m.dialects + 1);
    return ApiSuccess(m.products);
  }

  @override
  Future<ApiResult<int>> renameAttributeValue(int attributeId, String from, String to) async {
    lastValueRename = (attributeId, from, to);
    return const ApiSuccess(2);
  }

  @override
  Future<ApiResult<List<ProductProposal>>> propose(int? partnerId, List<Map<String, dynamic>> lines) async {
    lastProposePartner = partnerId;
    lastProposeLines = lines;
    return ApiSuccess([...proposals]);
  }

  @override
  Future<ApiResult<List<RegisteredProduct>>> register(int? partnerId, List<ProductProposal> items, {int? formatId}) async {
    lastRegistered = items;
    lastRegisterFormat = formatId;
    return ApiSuccess([
      for (final (i, p) in items.indexed)
        RegisteredProduct(
          row: p.row,
          janCode: p.janCode,
          productId: 500 + i,
          name: renderProductName('{base} {attr:size} {attr:color}', base: p.baseName, attributes: p.attributes),
        ),
    ]);
  }
}


/// Boxes and shipping weights (0115), in memory.
class FakePackagingRepository implements PackagingRepository {
  FakePackagingRepository({
    List<CartonType>? types,
    this.weight = const ShipmentWeightEstimate(),
  }) : types = types ??
            [
              const CartonType(id: 1, name: '80サイズ', lengthCm: 35, widthCm: 25, heightCm: 20,
                  emptyWeightG: 250, packingMaterialG: 50, maxLoadKg: 15),
              const CartonType(id: 2, name: '100サイズ', lengthCm: 40, widthCm: 30, heightCm: 30,
                  emptyWeightG: 400, packingMaterialG: 80, maxLoadKg: 20, isDefault: true),
            ];

  final List<CartonType> types;
  ShipmentWeightEstimate weight;
  final saved = <CartonType>[];
  final planned = <List<PlannedCarton>>[];
  final packaging = <({int cartonId, int typeId, double? empty, double? material})>[];

  @override
  Future<ApiResult<List<CartonType>>> cartonTypes({bool includeInactive = false}) async =>
      ApiSuccess(includeInactive ? types : types.where((t) => t.active).toList());

  @override
  Future<ApiResult<int>> saveCartonType(CartonType type) async {
    saved.add(type);
    return ApiSuccess(type.id ?? 99);
  }

  @override
  Future<ApiResult<ShipmentWeightEstimate>> estimate(int planId) async => ApiSuccess(weight);

  @override
  Future<ApiResult<ShipmentWeightEstimate>> setPlannedCartons(int planId, List<PlannedCarton> items) async {
    planned.add(items);
    return ApiSuccess(weight);
  }

  @override
  Future<ApiResult<bool>> setCartonPackaging(int cartonId,
      {required int cartonTypeId, double? emptyWeightG, double? packingMaterialG}) async {
    packaging.add((cartonId: cartonId, typeId: cartonTypeId, empty: emptyWeightG, material: packingMaterialG));
    return const ApiSuccess(true);
  }
}


/// 価格台帳 in memory (0124).
class FakePriceBookRepository implements PriceBookRepository {
  FakePriceBookRepository({
    List<PriceBookItem> items = const [],
    Map<int, List<PriceBookTerm>> history = const {},
  })  : items = List.of(items),
        histories = Map.of(history);

  final updates = <(int, Map<String, dynamic>)>[];

  @override
  Future<ApiResult<bool>> update(int itemId, Map<String, dynamic> fields) async {
    updates.add((itemId, fields));
    return const ApiSuccess(true);
  }

  List<PriceBookItem> items;
  Map<int, List<PriceBookTerm>> histories;
  final imports = <({List<Map<String, dynamic>> lines, int? partnerId, String? branch, DateTime? validFrom, String? file})>[];
  final addedTerms = <(int, Map<String, dynamic>)>[];
  final toMaster = <List<int>>[];
  final deleted = <List<int>>[];

  @override
  Future<ApiResult<List<PriceBookItem>>> list({String? search}) async => ApiSuccess([
        for (final i in items)
          if (search == null || i.name.contains(search) || (i.janCode ?? '').contains(search)) i,
      ]);

  @override
  Future<ApiResult<List<PriceBookTerm>>> history(int itemId) async => ApiSuccess(histories[itemId] ?? const []);

  @override
  Future<ApiResult<PriceBookImported>> import(List<Map<String, dynamic>> lines,
      {int? partnerId, String? branch, DateTime? validFrom, String? sourceFile}) async {
    imports.add((lines: lines, partnerId: partnerId, branch: branch, validFrom: validFrom, file: sourceFile));
    return ApiSuccess(PriceBookImported(
      created: lines.length,
      terms: partnerId == null ? 0 : lines.length,
      ids: [for (var i = 0; i < lines.length; i++) 1000 + i],
    ));
  }

  @override
  Future<ApiResult<List<PriceBookTerm>>> addTerm(int itemId, Map<String, dynamic> term) async {
    addedTerms.add((itemId, term));
    return ApiSuccess(histories[itemId] ?? const []);
  }

  @override
  Future<ApiResult<({int created, int linked, int skipped})>> toProducts(List<int> ids) async {
    toMaster.add(ids);
    items = [
      for (final i in items)
        if (ids.contains(i.id))
          PriceBookItem(
            id: i.id, name: i.name, janCode: i.janCode, maker: i.maker, itemCode: i.itemCode, terms: i.terms,
            stock: i.stock, termCount: i.termCount,
            product: PriceBookProductRef(id: 900 + i.id, name: i.name, lifecycle: ProductLifecycle.active, linked: true),
          )
        else
          i,
    ];
    return ApiSuccess((created: ids.length, linked: 0, skipped: 0));
  }

  @override
  Future<ApiResult<int>> delete(List<int> ids) async {
    deleted.add(ids);
    items = [for (final i in items) if (!ids.contains(i.id)) i];
    return ApiSuccess(ids.length);
  }
}

/// Kept files (0132), in memory.
class FakeEvidenceRepository implements EvidenceRepository {
  FakeEvidenceRepository([List<ImportDocument>? docs, this.bytes]) : docs = docs ?? [];

  final List<ImportDocument> docs;
  final Uint8List? bytes;
  final List<int> downloaded = [];
  EvidencePurpose? lastPurpose;
  String? lastSearch;

  @override
  Future<ApiResult<List<ImportDocument>>> list({EvidencePurpose? purpose, String? search}) async {
    lastPurpose = purpose;
    lastSearch = search;
    return ApiSuccess([
      for (final d in docs)
        if ((purpose == null || d.purpose == purpose) &&
            (search == null || search.isEmpty || d.fileName.contains(search) || (d.supplierName ?? '').contains(search)))
          d,
    ]);
  }

  @override
  Future<ApiResult<List<ImportDocument>>> forPlan({int? deliveryPlanId, int? shipmentPlanId}) async => ApiSuccess([
        for (final d in docs)
          if ((deliveryPlanId != null && d.deliveryPlanId == deliveryPlanId) ||
              (shipmentPlanId != null && d.shipmentPlanId == shipmentPlanId))
            d,
      ]);

  @override
  Future<ApiResult<Uint8List>> download(ImportDocument doc) async {
    downloaded.add(doc.id);
    return ApiSuccess(bytes ?? Uint8List(0));
  }
}

/// Our company (0131), in memory.
class FakeCompanyRepository implements CompanyRepository {
  FakeCompanyRepository({CompanyProfile? profile, this.suggested = const []})
      : profile_ = profile ?? const CompanyProfile(name: CompanyProfile.placeholder);

  CompanyProfile profile_;
  final List<OwnNameSuggestion> suggested;
  final List<CompanyProfile> saved = [];

  @override
  Future<ApiResult<CompanyProfile>> profile() async => ApiSuccess(profile_);

  @override
  Future<ApiResult<CompanyProfile>> save(CompanyProfile p) async {
    saved.add(p);
    profile_ = p;
    return ApiSuccess(p);
  }

  @override
  Future<ApiResult<List<OwnNameSuggestion>>> suggestions() async => ApiSuccess(suggested);
}


/// 仕入先ファイル起点の入荷 (0134–0136) in memory. [receiveFailures] are
/// answered in turn before receiving succeeds — e.g. an OVER_RECEIPT refusal
/// first, then the call with the operator's choice.
class FakeInboundRepository implements InboundRepository {
  FakeInboundRepository({
    this.receipt,
    this.duplicatesFound = const [],
    this.candidates = const {},
    this.todayCounts,
    this.history = const ProductInboundHistory(),
  });

  ExpectedReceipt? receipt;
  List<InboundDuplicate> duplicatesFound;
  Map<int, List<MatchCandidate>> candidates;
  InboundToday? todayCounts;
  ProductInboundHistory history;

  final List<String> receiveFailures = [];
  final List<({int planId, List<ReconcileEntry> entries, bool complete, DateTime? arrivedOn, OverReceiptChoice? over})>
      received = [];
  final List<({int planId, Map<String, dynamic> changes, int? documentId})> expectedSet = [];
  final List<({int inspectionId, DateTime date})> inspectionMoved = [];
  List<Map<String, dynamic>>? lastCandidateLines;

  @override
  Future<ApiResult<ExpectedReceipt>> timeline(int planId) async =>
      receipt == null ? const ApiFailure(message: 'not found', statusCode: 404) : ApiSuccess(receipt!);

  @override
  Future<ApiResult<bool>> setExpectedReceipt(int planId, Map<String, dynamic> changes, {int? documentId}) async {
    expectedSet.add((planId: planId, changes: changes, documentId: documentId));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<InboundDuplicate>>> duplicates({
    int? documentId,
    int? supplierId,
    String? supplierName,
    String? docNumber,
  }) async =>
      ApiSuccess(duplicatesFound);

  @override
  Future<ApiResult<ReceiveOutcome>> receiveDelivery(
    int planId, {
    required List<ReconcileEntry> entries,
    bool complete = false,
    String? noteReference,
    DateTime? arrivedOn,
    OverReceiptChoice? over,
  }) async {
    received.add((planId: planId, entries: entries, complete: complete, arrivedOn: arrivedOn, over: over));
    if (receiveFailures.isNotEmpty) return ApiFailure(message: receiveFailures.removeAt(0));
    return ApiSuccess(ReceiveOutcome(
      reconciliationId: 10,
      planId: planId,
      receiptState: ReceiptState.partiallyReceived,
      arrivedOn: arrivedOn,
      inspectionId: 20,
      scheduledInspectionDate: arrivedOn,
    ));
  }

  @override
  Future<ApiResult<bool>> setInspectionSchedule(int inspectionId, DateTime date) async {
    inspectionMoved.add((inspectionId: inspectionId, date: date));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<InboundToday>> today(int warehouseId) async =>
      todayCounts == null ? const ApiFailure(message: 'none') : ApiSuccess(todayCounts!);

  @override
  Future<ApiResult<Map<int, List<MatchCandidate>>>> matchCandidates(
    int? partnerId,
    List<Map<String, dynamic>> lines,
  ) async {
    lastCandidateLines = lines;
    return ApiSuccess(candidates);
  }

  @override
  Future<ApiResult<ProductInboundHistory>> productHistory(int productId) async => ApiSuccess(history);
}
