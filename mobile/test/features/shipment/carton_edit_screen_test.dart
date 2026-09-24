// Test fixtures are plain domain-object literals.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/shipment/application/shipment_providers.dart';
import 'package:wms_mobile/features/shipment/domain/carton.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';
import 'package:wms_mobile/features/shipment/presentation/carton_edit_screen.dart';

import '../../support/harness.dart';

/// §17/0079's additive, lot-aware packing (0076): pack_carton_item /
/// remove_carton_item / set_carton_label, read through shipment_packing
/// rather than the shipments edge function's lighter, unjoined cartons.
Shipment _shipment() => Shipment.fromJson(<String, dynamic>{
      'id': 1,
      'shipment_number': 'S-100',
      'customer_name': 'アクメ商事',
      'status': 'open',
      'lines': <dynamic>[],
      'cartons': <dynamic>[],
    });

Carton _openCarton({List<CartonItem> items = const []}) => Carton(
      id: 9,
      cartonNo: 1,
      items: items,
    );

ShipmentPacking _packing({
  int packed = 0,
  int packable = 100,
  List<CartonItem> items = const [],
  Carton? carton,
}) =>
    ShipmentPacking(
      shipmentPlanId: 1,
      lines: [
        PackableLine(
          productId: 7,
          janCode: '4900000000001',
          productName: 'ペン',
          packable: packable,
          packed: packed,
          unpacked: packable - packed,
        ),
      ],
      cartons: [carton ?? _openCarton(items: items)],
    );

void main() {
  testWidgets(
      'packing a parcel records it against the carton and shows the lot',
      (tester) async {
    final repo = FakeShipmentRepository([_shipment()], packingFixture: _packing());

    await pumpApp(
      tester,
      CartonEditScreen(shipment: _shipment(), carton: _openCarton()),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('梱包 0 / 100'), findsOneWidget);
    expect(find.text('残り 100'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '追加'));
    await tester.pumpAndSettle();

    // The quantity field starts at what is still outstanding.
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '梱包数'))
            .controller!
            .text,
        '100');
    await tester.enterText(find.widgetWithText(TextField, '梱包数'), '30');
    await tester.enterText(find.widgetWithText(TextField, 'ロット番号'), 'L-A');
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '追加')));
    await tester.pumpAndSettle();

    expect(find.textContaining('L:L-A'), findsOneWidget);
    expect(find.textContaining('× 30'), findsOneWidget);
    expect(find.text('梱包 30 / 100'), findsOneWidget);
    expect(find.text('残り 70'), findsOneWidget);
  });

  testWidgets(
      'a second parcel is bounded by what is left for the whole shipment',
      (tester) async {
    final repo = FakeShipmentRepository([_shipment()],
        packingFixture: _packing(
          packed: 40,
          items: [
            CartonItem(id: 501, janCode: '4900000000001', productName: 'ペン', quantity: 40, lotCode: 'L-A'),
          ],
        ));

    await pumpApp(
      tester,
      CartonEditScreen(shipment: _shipment(), carton: _openCarton()),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('梱包 40 / 100'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '追加'));
    await tester.pumpAndSettle();

    // Not the plan's full 100 — only the 60 still unpacked anywhere.
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '梱包数'))
            .controller!
            .text,
        '60');
  });

  testWidgets('removing a packed parcel takes it back off the carton',
      (tester) async {
    final repo = FakeShipmentRepository([_shipment()],
        packingFixture: _packing(
          packed: 30,
          items: [
            CartonItem(id: 501, janCode: '4900000000001', productName: 'ペン', quantity: 30, lotCode: 'L-A'),
          ],
        ));

    await pumpApp(
      tester,
      CartonEditScreen(shipment: _shipment(), carton: _openCarton()),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.textContaining('L:L-A'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.textContaining('L:L-A'), findsNothing);
    expect(find.text('梱包 0 / 100'), findsOneWidget);
    expect(find.text('まだ何も入っていません'), findsOneWidget);
  });

  testWidgets('a fully packed line shows done and offers no add button',
      (tester) async {
    final repo = FakeShipmentRepository([_shipment()],
        packingFixture: _packing(packed: 100, items: [
          CartonItem(id: 501, janCode: '4900000000001', productName: 'ペン', quantity: 100),
        ]));

    await pumpApp(
      tester,
      CartonEditScreen(shipment: _shipment(), carton: _openCarton()),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('梱包完了'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '追加'), findsNothing);
  });

  testWidgets("renaming a carton changes its label but not its contents",
      (tester) async {
    final repo = FakeShipmentRepository([_shipment()],
        packingFixture: _packing(
          packed: 30,
          items: [
            CartonItem(id: 501, janCode: '4900000000001', productName: 'ペン', quantity: 30, lotCode: 'L-A'),
          ],
        ));

    await pumpApp(
      tester,
      CartonEditScreen(shipment: _shipment(), carton: _openCarton()),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.byTooltip('名前を変更'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'A-1');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastRenamedCartonId, 9);
    expect(repo.lastCartonLabel, 'A-1');
    expect(find.textContaining('A-1'), findsOneWidget);
    // Still there — renaming must not have gone through the old
    // whole-carton replace, which would have wiped the lot.
    expect(find.textContaining('L:L-A'), findsOneWidget);
  });

  testWidgets('a packed (closed) carton cannot be edited from here',
      (tester) async {
    final closed = Carton(id: 9, cartonNo: 1, status: CartonStatus.packed, items: [
      CartonItem(id: 501, janCode: '4900000000001', productName: 'ペン', quantity: 30),
    ]);
    final repo = FakeShipmentRepository([_shipment()],
        packingFixture: _packing(packed: 30, carton: closed));

    await pumpApp(
      tester,
      CartonEditScreen(shipment: _shipment(), carton: closed),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('編集するには箱を開け直してください'), findsOneWidget);
    final addButton =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '追加'));
    expect(addButton.onPressed, isNull);
    expect(find.byIcon(Icons.close), findsNothing); // no remove button
  });
}
