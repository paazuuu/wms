import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/packing/domain/packing.dart';
import 'package:wms_mobile/features/shipment/domain/packaging.dart';

void main() {
  const s = CartonType(id: 1, name: 'S', lengthCm: 30, widthCm: 20, heightCm: 20, emptyWeightG: 300, maxLoadKg: 10);
  const m = CartonType(id: 2, name: 'M', lengthCm: 40, widthCm: 30, heightCm: 30, emptyWeightG: 500, packingMaterialG: 100);
  const l = CartonType(id: 3, name: 'L', lengthCm: 60, widthCm: 40, heightCm: 40, emptyWeightG: 900, isDefault: true);

  test('packMarkOf takes the letters of a 注番', () {
    expect(packMarkOf('BL  9E'), 'BL');
    expect(packMarkOf('hl12'), 'HL');
    expect(packMarkOf('123'), '');
    expect(packMarkOf(null), '');
  });

  test('full cases go in their own case, the rest into our cartons', () {
    final boxes = planPacking(
      const [PackDemand(fileLineId: 1, productId: 10, jan: '4909999000014', name: 'A', quantity: 50, unitWeightG: 100, mark: 'HL')],
      casePacks: const {10: CasePack(productId: 10, caseQuantity: 24, lengthCm: 30, widthCm: 20, heightCm: 10, grossKg: 2.6)},
      cartons: const [l, s, m],
    );
    expect(boxes, hasLength(3));
    expect(boxes[0].ownCase, isTrue);
    expect(boxes[0].estKg, 2.6);
    expect(boxes[0].items.single.quantity, 24);
    expect(boxes[1].ownCase, isTrue);
    // 2 left: 0.25 L each, so the smallest carton, at 0.2 kg + its 0.3 kg.
    expect(boxes[2].ownCase, isFalse);
    expect(boxes[2].cartonType, 'S');
    expect(boxes[2].items.single.quantity, 2);
    expect(boxes[2].estKg, 0.5);
    expect(boxes.map((b) => b.label), ['HL-1', 'HL-2', 'HL-3']);
  });

  test('each mark is numbered from 1 and the weight limit splits a box', () {
    final boxes = planPacking(
      const [
        PackDemand(fileLineId: 1, productId: 1, name: 'heavy', quantity: 30, unitWeightG: 1000, mark: 'BL'),
        PackDemand(fileLineId: 2, productId: 2, name: 'light', quantity: 3, unitWeightG: 100, mark: 'HL'),
      ],
      cartons: const [s, m, l],
      maxKg: 20,
    );
    final bl = boxes.where((b) => b.mark == 'BL').toList();
    final hl = boxes.where((b) => b.mark == 'HL').toList();
    expect(bl.map((b) => b.quantity), [20, 10]);
    expect(bl.map((b) => b.boxNo), [1, 2]);
    expect(hl.single.boxNo, 1);
    // 10 kg is within S's 10 kg limit.
    expect(bl[1].cartonType, 'S');
    expect(bl[0].cartonType, 'M');
    expect(bl[0].estKg, 20.6);
  });

  test('small items share a box; a unit with nothing to measure by gets its own', () {
    final boxes = planPacking(
      const [
        PackDemand(fileLineId: 1, productId: 1, name: 'a', quantity: 2, unitWeightG: 500),
        PackDemand(fileLineId: 2, productId: 2, name: 'b', quantity: 3, unitWeightG: 200),
        PackDemand(fileLineId: 3, name: 'unknown', quantity: 4),
      ],
      cartons: const [s, m, l],
    );
    expect(boxes, hasLength(2));
    expect(boxes[0].items.map((i) => i.name), ['a', 'b']);
    expect(boxes[0].estKg, 1.9);
    expect(boxes[1].items.single.name, 'unknown');
    expect(boxes[1].cartonType, 'L', reason: 'the usual carton');
    expect(boxes[1].estKg, isNull);
    expect(boxes.map((b) => b.label), ['1', '2']);
  });

  test('a unit too heavy for any carton still goes in one, alone', () {
    final boxes = planPacking(
      const [PackDemand(fileLineId: 1, productId: 1, name: 'anvil', quantity: 2, unitWeightG: 30000)],
      cartons: const [m],
      maxKg: 20,
    );
    expect(boxes.map((b) => b.quantity), [1, 1]);
  });

  test('with no cartons registered, each line is a box of its own', () {
    final boxes = planPacking(const [
      PackDemand(fileLineId: 1, productId: 1, name: 'a', quantity: 2, unitWeightG: 500),
      PackDemand(fileLineId: 2, productId: 2, name: 'b', quantity: 1, unitWeightG: 500),
    ]);
    expect(boxes, hasLength(2));
    expect(boxes.first.cartonType, isNull);
    expect(boxes.first.estKg, 1.0);
  });

  test('packingDifferences names what does not add up', () {
    const demands = [
      PackDemand(productId: 1, name: 'a', quantity: 5),
      PackDemand(productId: 2, name: 'b', quantity: 2),
    ];
    final boxes = [
      const PackBox(boxNo: 1, items: [PackItem(productId: 1, name: 'a', quantity: 5), PackItem(productId: 2, name: 'b', quantity: 1)]),
      const PackBox(boxNo: 2, items: [PackItem(jan: '4909999000021', name: 'c', quantity: 1)]),
    ];
    expect(packingDifferences(demands, boxes), [('b', 2, 1), ('c', 0, 1)]);
    expect(packingDifferences(demands, planPacking(demands)), isEmpty);
  });

  test('a box goes to JSON and back', () {
    const b = PackBox(boxNo: 3, mark: 'HL', cartonTypeId: 2, lengthCm: 40, widthCm: 30, heightCm: 30, estKg: 5.5, items: [
      PackItem(fileLineId: 1, productId: 1, jan: '4909999000014', name: 'a', quantity: 2),
    ]);
    final j = b.toJson();
    expect(j['lines'], hasLength(1));
    final back = PackBox.fromJson({...j, 'lines': j['lines']});
    expect(back.label, 'HL-3');
    expect(back.sizeText, '40 × 30 × 30');
    expect(back.volumeM3, closeTo(0.036, 1e-9));
    expect(back.items.single.quantity, 2);
  });
}
