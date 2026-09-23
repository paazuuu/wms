// Test fixtures are plain JSON-shaped literals.
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/shipment/application/shipment_providers.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';
import 'package:wms_mobile/features/shipment/presentation/carton_edit_screen.dart';
import 'package:wms_mobile/features/shipment/presentation/shipment_detail_screen.dart';

import '../../support/harness.dart';

Shipment _shipment() => Shipment.fromJson(<String, dynamic>{
      'id': 1,
      'shipment_number': 'S-100',
      'customer_name': 'アクメ商事',
      'reference_no': 'ACME-00001',
      'status': 'open',
      'lines': <dynamic>[
        <String, dynamic>{
          'id': 1,
          'jan_code': '4902505632037',
          'product_name': 'ペン',
          'quantity': 100,
        },
      ],
      'cartons': <dynamic>[
        <String, dynamic>{
          'id': 9,
          'carton_no': 1,
          'label': 'A-1',
          'items': <dynamic>[
            <String, dynamic>{
              'jan_code': '4902505632037',
              'product_name': 'ペン',
              'quantity': 60,
            },
          ],
        },
      ],
    });


/// No cartons yet: 237 pieces waiting to be boxed, the §18 example.
Shipment _unpacked() => Shipment.fromJson(<String, dynamic>{
      'id': 2,
      'shipment_number': 'S-200',
      'customer_name': 'アクメ商事',
      'status': 'open',
      'lines': <dynamic>[
        <String, dynamic>{
          'id': 1,
          'jan_code': '4988601001053',
          'product_name': 'ペン',
          'quantity': 237,
        },
      ],
      'cartons': <dynamic>[],
    });

/// IconButtons in this screen are identified by their tooltip, same as an
/// operator would find them.
Finder _iconButton(String tooltip) =>
    find.byWidgetPredicate((w) => w is IconButton && w.tooltip == tooltip);

void main() {
  testWidgets('shows header, carton and the confirm action', (tester) async {
    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 1),
      overrides: [
        shipmentRepositoryProvider
            .overrideWithValue(FakeShipmentRepository([_shipment()])),
      ],
    );

    // Header shows the customer and reference.
    expect(find.text('アクメ商事'), findsOneWidget);
    expect(find.textContaining('ACME-00001'), findsWidgets);
    // The line and carton render.
    expect(find.text('ペン'), findsWidgets);
    expect(find.textContaining('段ボール #1'), findsOneWidget);
    // Sticky confirm action for an open shipment.
    expect(find.text('出庫確定'), findsOneWidget);
  });

  testWidgets(
      'a permission-denied ship shows the friendly message, not the raw RPC text (§34)',
      (tester) async {
    final repo = FakeShipmentRepository([_shipment()])
      ..failWith = 'not permitted: ship.complete required';

    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 1),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('出庫確定'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '出庫確定').last);
    await tester.pumpAndSettle();

    expect(find.text('この操作を行う権限がありません。'), findsOneWidget);
    expect(find.textContaining('ship.complete'), findsNothing);
  });

  testWidgets(
      'a permission-denied add-carton shows the friendly message, not the raw RPC text (§34)',
      (tester) async {
    final repo = FakeShipmentRepository([_shipment()])
      ..failWith = 'not permitted: pack.complete required';

    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 1),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('段ボールを追加'));
    await tester.pumpAndSettle();

    expect(find.text('この操作を行う権限がありません。'), findsOneWidget);
    expect(find.textContaining('pack.complete'), findsNothing);
  });

  testWidgets('§18 shows the computed box count before creating anything',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeShipmentRepository([_unpacked()]);

    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 2),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('箱数を自動計算'));
    await tester.pumpAndSettle();

    expect(find.text('総数量 237'), findsOneWidget);
    // Nothing computed until a box size is given — the dialog explains instead.
    expect(find.text('1箱に入る数量を入力すると、必要な箱数を計算します。'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '24');
    await tester.pumpAndSettle();

    // The arithmetic the spec says not to make the operator do.
    expect(find.text('箱数 10'), findsOneWidget);
    expect(find.text('9 箱 × 24 個 ＋ 最終箱 21 個'), findsOneWidget);
    // Still nothing created — this is a preview.
    expect(repo.lastUnitsPerCarton, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'この箱数で作成'));
    await tester.pumpAndSettle();

    expect(repo.lastUnitsPerCarton, 24);
  });

  testWidgets('an even split does not claim a different last box',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 2),
      overrides: [
        shipmentRepositoryProvider
            .overrideWithValue(FakeShipmentRepository([_unpacked()])),
      ],
    );

    await tester.tap(find.text('箱数を自動計算'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '237');
    await tester.pumpAndSettle();

    expect(find.text('箱数 1'), findsOneWidget);
    expect(find.text('全箱 237 個'), findsOneWidget);
  });

  testWidgets('§21 logistics start unset and round-trip through the sheet',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeShipmentRepository([_shipment()]);

    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 1),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('配送情報'), findsOneWidget);
    // "Not weighed yet" and "weighs nothing" are different facts.
    expect(find.text('未入力'), findsNWidgets(3));

    await tester.tap(find.widgetWithText(TextButton, '編集'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '重量'), '12.4');
    await tester.tap(find.widgetWithText(ActionChip, 'ヤマト運輸'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, '送り状番号'), '1234-5678-9012');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastLogistics, (12.4, 'ヤマト運輸', '1234-5678-9012'));
  });

  testWidgets('a negative weight is refused before it reaches the server',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeShipmentRepository([_shipment()]);

    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 1),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.widgetWithText(TextButton, '編集'));
    await tester.pumpAndSettle();
    // The field only accepts digits and a dot, so a bad value gets there by
    // typing "1.2.3" rather than a minus sign.
    await tester.enterText(find.widgetWithText(TextField, '重量'), '1.2.3');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('重量は0以上の数値で入力してください'), findsOneWidget);
    expect(repo.lastLogistics, isNull);
  });

  // §17 / 0076 — the box's own lifecycle and per-box facts.

  testWidgets('an open carton with items can be closed', (tester) async {
    final repo = FakeShipmentRepository([_shipment()]);

    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 1),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('梱包中'), findsOneWidget);

    await tester.tap(_iconButton('箱を閉じる'));
    await tester.pumpAndSettle();

    expect(repo.lastClosedCartonId, 9);
  });

  testWidgets("an empty carton's close button stays disabled",
      (tester) async {
    final empty = Shipment.fromJson(<String, dynamic>{
      'id': 3,
      'shipment_number': 'S-300',
      'customer_name': 'アクメ商事',
      'status': 'open',
      'lines': <dynamic>[],
      'cartons': <dynamic>[
        <String, dynamic>{'id': 20, 'carton_no': 1, 'items': <dynamic>[]},
      ],
    });

    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 3),
      overrides: [
        shipmentRepositoryProvider.overrideWithValue(FakeShipmentRepository([empty])),
      ],
    );

    final button = tester.widget<IconButton>(
        _iconButton('空の箱は閉じられません'));
    expect(button.onPressed, isNull);
  });

  testWidgets('a packed carton offers reopen and cannot be edited from here',
      (tester) async {
    final packed = Shipment.fromJson(<String, dynamic>{
      'id': 4,
      'shipment_number': 'S-400',
      'customer_name': 'アクメ商事',
      'status': 'packing',
      'lines': <dynamic>[
        <String, dynamic>{
          'id': 1,
          'jan_code': '4902505632037',
          'product_name': 'ペン',
          'quantity': 60,
        },
      ],
      'cartons': <dynamic>[
        <String, dynamic>{
          'id': 30,
          'carton_no': 1,
          'status': 'PACKED',
          'items': <dynamic>[
            <String, dynamic>{
              'jan_code': '4902505632037',
              'product_name': 'ペン',
              'quantity': 60,
            },
          ],
        },
      ],
    });
    final repo = FakeShipmentRepository([packed]);

    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 4),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('梱包済み'), findsOneWidget);
    expect(find.text('編集するには箱を開け直してください'), findsOneWidget);
    // No close button while it is already closed.
    expect(find.byTooltip('箱を閉じる'), findsNothing);

    await tester.tap(find.text('段ボール #1')); // tapping the (non-editable) card
    await tester.pumpAndSettle();
    expect(find.byType(CartonEditScreen), findsNothing);

    await tester.tap(_iconButton('箱を開け直す'));
    await tester.pumpAndSettle();

    expect(repo.lastReopenedCartonId, 30);
  });

  testWidgets('measurements pre-fill from the carton and round-trip through the sheet',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final measured = Shipment.fromJson(<String, dynamic>{
      'id': 5,
      'shipment_number': 'S-500',
      'customer_name': 'アクメ商事',
      'status': 'open',
      'lines': <dynamic>[],
      'cartons': <dynamic>[
        <String, dynamic>{
          'id': 40,
          'carton_no': 1,
          'carton_type': '60サイズ',
          'weight_kg': 1.5,
          'length_cm': 20,
          'width_cm': 15,
          'height_cm': 10,
          'tracking_number': 'YAMATO-123',
          'items': <dynamic>[],
        },
      ],
    });
    final repo = FakeShipmentRepository([measured]);

    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 5),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    // The card already shows the deterministic (non-weight) facts.
    expect(find.text('20 × 15 × 10 cm'), findsOneWidget);
    expect(find.text('YAMATO-123'), findsOneWidget);

    await tester.tap(_iconButton('サイズ・重量を編集'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '重量').evaluate().isNotEmpty, isTrue);
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '重量'))
            .controller!
            .text,
        '1.5');
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '長さ'))
            .controller!
            .text,
        '20');
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '送り状番号'))
            .controller!
            .text,
        'YAMATO-123');

    await tester.enterText(find.widgetWithText(TextField, '重量'), '2.5');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastCartonMeasurements, (40, 2.5, 20.0, 15.0, 10.0, '60サイズ', 'YAMATO-123'));
  });

  testWidgets('clearing a measurement field clears it rather than zeroing it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeShipmentRepository([_shipment()]);

    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 1),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(_iconButton('サイズ・重量を編集'));
    await tester.pumpAndSettle();

    // Nothing was set yet, so every field starts blank.
    await tester.enterText(find.widgetWithText(TextField, '重量'), '3');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastCartonMeasurements, (9, 3.0, null, null, null, null, null));
  });

  testWidgets('an invalid measurement is refused before it reaches the server',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeShipmentRepository([_shipment()]);

    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 1),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(_iconButton('サイズ・重量を編集'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '長さ'), '1.2.3');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('重量は0以上の数値で入力してください'), findsOneWidget);
    expect(repo.lastCartonMeasurements, isNull);
  });
}
