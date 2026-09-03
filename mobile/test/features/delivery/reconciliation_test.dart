import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan_line.dart';
import 'package:wms_mobile/features/delivery/domain/reconciliation.dart';

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

CountedItem _c(String jan, int qty,
        [CountSource source = CountSource.scan]) =>
    CountedItem(janCode: jan, quantity: qty, source: source);

void main() {
  test('all planned lines pending when nothing counted', () {
    final result = buildReconciliation(_plan(), const {});
    expect(result.lines.length, 2);
    expect(result.pendingCount, 2);
    expect(result.matchedCount, 0);
    expect(result.hasDiscrepancies, isFalse);
    expect(result.isClean, isFalse); // pending is not clean
  });

  test('exact counts mark every line matched and clean', () {
    final result = buildReconciliation(_plan(), {
      '4902505632037': _c('4902505632037', 100),
      '4901480241418': _c('4901480241418', 20),
    });
    expect(result.matchedCount, 2);
    expect(result.pendingCount, 0);
    expect(result.isClean, isTrue);
    expect(result.hasDiscrepancies, isFalse);
  });

  test('fewer than planned is a shortfall with a negative difference', () {
    final result = buildReconciliation(_plan(), {
      '4902505632037': _c('4902505632037', 60),
    });
    final penLine =
        result.lines.firstWhere((l) => l.janCode == '4902505632037');
    expect(penLine.status, ReconLineStatus.shortfall);
    expect(penLine.difference, -40);
    expect(result.shortfallCount, 1);
    expect(result.hasDiscrepancies, isTrue);
  });

  test('more than planned is an over with a positive difference', () {
    final result = buildReconciliation(_plan(), {
      '4901480241418': _c('4901480241418', 25),
    });
    final line =
        result.lines.firstWhere((l) => l.janCode == '4901480241418');
    expect(line.status, ReconLineStatus.over);
    expect(line.difference, 5);
    expect(result.overCount, 1);
  });

  test('a JAN not on the plan appears as an unexpected line, appended last', () {
    final result = buildReconciliation(_plan(), {
      '4902505632037': _c('4902505632037', 100),
      '4560000000004': _c('4560000000004', 3),
    });
    expect(result.lines.length, 3);
    expect(result.lines.last.janCode, '4560000000004');
    expect(result.lines.last.status, ReconLineStatus.unexpected);
    expect(result.lines.last.planLine, isNull);
    expect(result.unexpectedCount, 1);
    expect(result.hasDiscrepancies, isTrue);
  });

  test('plan order is preserved for planned lines', () {
    final result = buildReconciliation(_plan(), const {});
    expect(result.lines.map((l) => l.janCode),
        ['4902505632037', '4901480241418']);
  });
}
