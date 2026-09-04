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

  group('split delivery (cumulative received)', () {
    DeliveryPlan partlyReceived() => const DeliveryPlan(
          id: 1,
          deliveryNumber: '0901',
          lines: [
            // 60 of 100 already arrived on an earlier delivery.
            DeliveryPlanLine(
                id: 10,
                janCode: '4902505632037',
                productName: 'Pen',
                plannedQuantity: 100,
                receivedQuantity: 60),
            DeliveryPlanLine(
                id: 11,
                janCode: '4901480241418',
                productName: 'Stapler',
                plannedQuantity: 20,
                receivedQuantity: 20),
          ],
        );

    test('a fully-received line reads matched even with nothing counted now',
        () {
      final result = buildReconciliation(partlyReceived(), const {});
      final stapler =
          result.lines.firstWhere((l) => l.janCode == '4901480241418');
      expect(stapler.status, ReconLineStatus.matched);
      expect(stapler.remaining, 0);
    });

    test('a partly-received line is short until the remainder arrives', () {
      final result = buildReconciliation(partlyReceived(), const {});
      final pen =
          result.lines.firstWhere((l) => l.janCode == '4902505632037');
      expect(pen.status, ReconLineStatus.shortfall);
      expect(pen.alreadyReceived, 60);
      expect(pen.remaining, 40);
      expect(result.outstandingTotal, 40);
      expect(result.hasOutstanding, isTrue);
    });

    test('counting the remainder clears the outstanding amount', () {
      final result = buildReconciliation(partlyReceived(), {
        '4902505632037': _c('4902505632037', 40),
      });
      final pen =
          result.lines.firstWhere((l) => l.janCode == '4902505632037');
      expect(pen.receivedTotal, 100);
      expect(pen.status, ReconLineStatus.matched);
      expect(pen.remaining, 0);
      expect(result.outstandingTotal, 0);
      expect(result.hasOutstanding, isFalse);
    });

    test('over-receiving the remainder is flagged over', () {
      final result = buildReconciliation(partlyReceived(), {
        '4902505632037': _c('4902505632037', 50),
      });
      final pen =
          result.lines.firstWhere((l) => l.janCode == '4902505632037');
      expect(pen.receivedTotal, 110);
      expect(pen.status, ReconLineStatus.over);
      expect(pen.remaining, 0);
    });
  });

  test('a differently-formatted counted JAN still matches the plan', () {
    // Plan stores a clean 13-digit code; the count arrives hyphenated + with a
    // full-width digit. Canonical matching must treat them as the same item.
    final result = buildReconciliation(_plan(), {
      '４902-505-632037': _c('４902-505-632037', 100),
    });
    final pen =
        result.lines.firstWhere((l) => l.planLine?.janCode == '4902505632037');
    expect(pen.status, ReconLineStatus.matched);
    expect(result.unexpectedCount, 0);
  });
}
