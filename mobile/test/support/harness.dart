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
import 'package:wms_mobile/features/shipment/data/shipment_repository.dart';
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

class FakeStockRepository implements StockRepository {
  FakeStockRepository(this.items);
  final List<StockItem> items;

  @override
  Future<ApiResult<List<StockItem>>> list() async => ApiSuccess(items);
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
