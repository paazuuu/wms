import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/delivery/application/reconciliation_controller.dart';
import 'package:wms_mobile/features/delivery/data/delivery_repository.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan_line.dart';
import 'package:wms_mobile/features/delivery/domain/ocr_line.dart';
import 'package:wms_mobile/features/delivery/domain/reconciliation.dart';

class _FakeRepo implements DeliveryRepository {
  List<ReconcileEntry>? lastEntries;

  @override
  Future<ApiResult<List<DeliveryPlan>>> list({String? status, String? search}) async =>
      const ApiSuccess([]);

  @override
  Future<ApiResult<DeliveryPlan>> show(int id) async =>
      ApiSuccess(_plan());

  @override
  Future<ApiResult<PlanImportResult>> importPlan({
    required MultipartFile file,
    required String deliveryNumber,
    String? supplier,
  }) async =>
      const ApiSuccess(
          PlanImportResult(planId: 1, lineCount: 0, totalQuantity: 0));

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
}
