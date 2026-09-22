// ignore_for_file: prefer_const_constructors
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/delivery/application/reconciliation_controller.dart';
import 'package:wms_mobile/features/delivery/data/delivery_repository.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan_line.dart';
import 'package:wms_mobile/features/delivery/domain/ocr_line.dart';
import 'package:wms_mobile/features/delivery/domain/receipt.dart';
import 'package:wms_mobile/features/delivery/domain/receipt_detail.dart';
import 'package:wms_mobile/features/delivery/domain/reconciliation.dart';

class _FakeRepo implements DeliveryRepository {
  List<ReconcileEntry>? lastEntries;

  @override
  Future<ApiResult<ReceiptDetail>> receiptDetail(int reconciliationId) async =>
      const ApiFailure(message: 'not used here', statusCode: 404);

  @override
  Future<ApiResult<List<LotProvenance>>> lotProvenance(
    int productId, {
    String? lotCode,
  }) async =>
      const ApiSuccess([]);

  @override
  Future<ApiResult<List<DeliveryPlan>>> list(
          {String? status, String? search, int? warehouseId}) async =>
      const ApiSuccess([]);

  @override
  Future<ApiResult<DeliveryPlan>> show(int id) async =>
      ApiSuccess(_plan());

  @override
  Future<ApiResult<ImportPreview>> previewPlan({
    required MultipartFile file,
    String? deliveryNumber,
    String? supplier,
    String? supplierCode,
  }) async =>
      const ApiSuccess(ImportPreview(
          source: 'test', lineCount: 0, totalQuantity: 0, lines: []));

  @override
  Future<ApiResult<PlanImportResult>> commitPlan(PlanCommit commit) async =>
      const ApiSuccess(
          PlanImportResult(planId: 1, lineCount: 0, totalQuantity: 0));

  @override
  Future<ApiResult<List<Receipt>>> receipts(int planId) async =>
      const ApiSuccess([]);

  @override
  Future<ApiResult<DeliveryPlan>> cancelReceipt(
          int planId, int receiptId) async =>
      ApiSuccess(_plan());

  @override
  Future<ApiResult<DeliveryPlan>> reconcile(
    int id, {
    required List<ReconcileEntry> entries,
    String? noteReference,
    bool complete = true,
  }) async {
    lastEntries = entries;
    return ApiSuccess(_plan());
  }
}

DeliveryPlan _plan() => const DeliveryPlan(
      id: 1,
      deliveryNumber: '0901',
      lines: [
        DeliveryPlanLine(
            id: 10,
            janCode: '4902505632037',
            productName: 'Pen',
            plannedQuantity: 100),
        DeliveryPlanLine(
            id: 11,
            janCode: '4901480241418',
            productName: 'Stapler',
            plannedQuantity: 20),
      ],
    );

void main() {
  test('recordScan increments the counted quantity', () {
    final c = ReconciliationController(_FakeRepo(), _plan());
    c.recordScan('4902505632037');
    c.recordScan('4902505632037');
    c.recordScan('4902505632037');
    final line = c.state.result.lines
        .firstWhere((l) => l.janCode == '4902505632037');
    expect(line.actualQuantity, 3);
    expect(line.source, CountSource.scan);
  });

  test('applyOcr seeds planned quantity but never overwrites a scan', () {
    final c = ReconciliationController(_FakeRepo(), _plan());
    // Operator scanned 5 of the pen already.
    c.setQuantity('4902505632037', 5, source: CountSource.scan);
    // OCR sees both JANs on the note.
    c.applyOcr(const [
      OcrLine(janCode: '4902505632037'),
      OcrLine(janCode: '4901480241418'),
    ]);
    final pen = c.state.result.lines
        .firstWhere((l) => l.janCode == '4902505632037');
    final stapler = c.state.result.lines
        .firstWhere((l) => l.janCode == '4901480241418');
    // Scan preserved.
    expect(pen.actualQuantity, 5);
    expect(pen.source, CountSource.scan);
    // OCR seeded the untouched line to its planned quantity.
    expect(stapler.actualQuantity, 20);
    expect(stapler.source, CountSource.ocr);
  });

  test('setQuantity to zero clears the line back to pending', () {
    final c = ReconciliationController(_FakeRepo(), _plan());
    c.setQuantity('4902505632037', 4);
    c.setQuantity('4902505632037', 0);
    final line = c.state.result.lines
        .firstWhere((l) => l.janCode == '4902505632037');
    expect(line.actualQuantity, 0);
    expect(line.status, ReconLineStatus.pending);
  });

  test('submit sends one entry per counted JAN with the plan line id', () async {
    final repo = _FakeRepo();
    final c = ReconciliationController(repo, _plan());
    c.recordScan('4902505632037');
    await c.submit();
    expect(repo.lastEntries, isNotNull);
    expect(repo.lastEntries!.length, 1);
    expect(repo.lastEntries!.single.janCode, '4902505632037');
    expect(repo.lastEntries!.single.lineId, 10);
  });

  group('ReconciliationController parcels', () {
    // This file's plan has two lines; the parcel tests work on the first.
    const jan = '4902505632037';

    late _FakeRepo repo;
    late ReconciliationController controller;

    setUp(() {
      repo = _FakeRepo();
      controller = ReconciliationController(repo, _plan());
    });

    test('a parcel raises the line to cover it', () {
      controller.addParcel(jan, ReceivedParcel(quantity: 20, lotCode: 'L-A'));

      final counted = controller.state.counts[jan]!;
      // A parcel in the operator's hands is stock that arrived, so the line
      // cannot be lower than its parcels — the server refuses that anyway.
      expect(counted.quantity, 20);
      expect(counted.parcels, hasLength(1));
    });

    test('a parcel inside an existing count leaves the count alone', () {
      controller.setQuantity(jan, 40);
      controller.addParcel(jan, ReceivedParcel(quantity: 20, lotCode: 'L-A'));

      final counted = controller.state.counts[jan]!;
      expect(counted.quantity, 40);
      expect(counted.unattributedQuantity, 20);
    });

    test('scanning more units keeps the parcels already recorded', () {
      controller.setQuantity(jan, 20);
      controller.addParcel(jan, ReceivedParcel(quantity: 20, lotCode: 'L-A'));
      controller.recordScan(jan);

      final counted = controller.state.counts[jan]!;
      expect(counted.quantity, 21);
      // Throwing the lot away because someone scanned one more carton would be
      // the worst possible trade.
      expect(counted.parcels, hasLength(1));
      expect(counted.parcels.single.lotCode, 'L-A');
    });

    test('removing a parcel leaves the counted total alone', () {
      controller.setQuantity(jan, 40);
      controller.addParcel(jan, ReceivedParcel(quantity: 20, lotCode: 'L-A'));
      controller.removeParcel(jan, 0);

      final counted = controller.state.counts[jan]!;
      // The lot may have been mis-keyed on a carton that did arrive.
      expect(counted.quantity, 40);
      expect(counted.parcels, isEmpty);
    });

    test('the reconciliation view carries the parcels and the remainder', () {
      controller.setQuantity(jan, 40);
      controller.addParcel(jan, ReceivedParcel(quantity: 20, lotCode: 'L-A'));
      controller.addParcel(jan, ReceivedParcel(quantity: 15, lotCode: 'L-B'));

      final line =
          controller.state.result.lines.firstWhere((l) => l.janCode == jan);
      expect(line.parcels, hasLength(2));
      expect(line.parcelledQuantity, 35);
      expect(line.unattributedQuantity, 5);
      expect(controller.state.result.hasOverParcelledLine, isFalse);
    });

    test('an over-parcelled line is visible to the screen before the submit', () {
      controller.setQuantity(jan, 10);
      // Raises the line to 12, so this alone cannot over-parcel…
      controller.addParcel(jan, ReceivedParcel(quantity: 12));
      expect(controller.state.result.hasOverParcelledLine, isFalse);
      // …but lowering the count afterwards can, and that is the state the
      // server refuses, so the screen has to be able to see it.
      controller.setQuantity(jan, 5);
      expect(controller.state.result.hasOverParcelledLine, isTrue);
    });

    test('submitting sends the parcels as items on their line', () async {
      controller.setQuantity(jan, 40);
      controller.addParcel(
        jan,
        ReceivedParcel(
            quantity: 20, lotCode: 'L-A', expiry: DateTime(2026, 12, 20)),
      );

      await controller.submit(noteReference: 'NOTE-1');

      final entry =
          repo.lastEntries!.firstWhere((e) => e.janCode == jan);
      final json = entry.toJson();
      expect(json['jan_code'], jan);
      expect(json['actual_quantity'], 40);
      final items = json['items'] as List;
      expect(items, hasLength(1));
      expect((items.single as Map)['lot_code'], 'L-A');
      expect((items.single as Map)['expiry'], '2026-12-20');
    });

    test('a plain count sends no items key at all', () async {
      controller.setQuantity(jan, 40);

      await controller.submit();

      // An empty array and an absent key mean the same thing to the server, and
      // omitting it keeps a plain count's payload exactly as it was before 0067.
      expect(
          repo.lastEntries!
              .firstWhere((e) => e.janCode == jan)
              .toJson()
              .containsKey('items'),
          isFalse);
    });
  });
}
