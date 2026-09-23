// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/shipment/application/shipment_providers.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';
import 'package:wms_mobile/features/wave/application/pick_wave_providers.dart';
import 'package:wms_mobile/features/wave/domain/pick_wave.dart';
import 'package:wms_mobile/features/wave/presentation/pick_wave_detail_screen.dart';
import 'package:wms_mobile/features/wave/presentation/pick_wave_list_screen.dart';
import 'package:wms_mobile/features/wave/presentation/pick_wave_sheet_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

/// §15's payoff, in fixture form: three shipments each wanting 10 of the same
/// parcel become one stop of 30 on the sheet.
PickWave _threeOrderWave() => const PickWave(
      id: 1,
      code: 'WV-000001',
      warehouseId: 1,
      status: PickWaveStatus.picking,
      assignedTo: 'user-1',
      assignedToName: 'ピッカー花子',
      taskCount: 3,
      pickedCount: 0,
      lists: [
        PickWaveList(
            pickListId: 10,
            shipmentPlanId: 100,
            shipmentNumber: 'SHP-100',
            customerName: '得意先A',
            status: 'PICKING',
            taskCount: 1,
            pickedCount: 0),
        PickWaveList(
            pickListId: 11,
            shipmentPlanId: 101,
            shipmentNumber: 'SHP-101',
            customerName: '得意先B',
            status: 'PICKING',
            taskCount: 1,
            pickedCount: 0),
        PickWaveList(
            pickListId: 12,
            shipmentPlanId: 102,
            shipmentNumber: 'SHP-102',
            customerName: '得意先C',
            status: 'PICKING',
            taskCount: 1,
            pickedCount: 0),
      ],
    );

WavePickPlan _threeOrderSheet() => const WavePickPlan(
      waveId: 1,
      warehouseId: 1,
      totalUnits: 30,
      stops: [
        WaveStop(
          binId: 3,
          binCode: 'R-01-A',
          productId: 7,
          janCode: '4900000000001',
          productName: 'ペン',
          lotId: 2,
          lotCode: 'L-B',
          expiryDate: '2027-01-01',
          stockUnitId: 40,
          quantity: 30,
          lines: [
            WaveStopLine(taskId: 1, pickListId: 10, shipmentPlanId: 100, quantity: 10),
            WaveStopLine(taskId: 2, pickListId: 11, shipmentPlanId: 101, quantity: 10),
            WaveStopLine(taskId: 3, pickListId: 12, shipmentPlanId: 102, quantity: 10),
          ],
        ),
      ],
      short: [
        WaveShort(
            taskId: 4, janCode: '4900000000002', short: 5, reason: 'not_enough_shippable_stock'),
      ],
    );

void main() {
  testWidgets('the empty state explains what a wave is for', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final container = ProviderContainer(overrides: [
      ..._baseOverrides(),
      pickWaveRepositoryProvider.overrideWithValue(FakePickWaveRepository()),
    ]);
    addTearDown(container.dispose);
    await pumpAppWith(tester, container, const PickWaveListScreen());

    expect(find.text('ウェーブがまだありません'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('creating a wave from several shipments opens its detail screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final waveRepo = FakePickWaveRepository()
      ..createResult = const CreatePickWaveResult(
          waveId: 1, code: 'WV-000001', pickListIds: [10, 11], skipped: []);
    final shipmentRepo = FakeShipmentRepository(const [
      Shipment(id: 100, shipmentNumber: 'SHP-100', customerName: '得意先A', lines: []),
      Shipment(id: 101, shipmentNumber: 'SHP-101', customerName: '得意先B', lines: []),
    ]);
    final container = ProviderContainer(overrides: [
      ..._baseOverrides(),
      pickWaveRepositoryProvider.overrideWithValue(waveRepo),
      shipmentRepositoryProvider.overrideWithValue(shipmentRepo),
      pickWaveDetailProvider(1).overrideWith((ref) async => _threeOrderWave()),
    ]);
    addTearDown(container.dispose);
    container.read(activeWarehouseIdProvider.notifier).state = 1;
    await pumpAppWith(tester, container, const PickWaveListScreen());

    await tester.tap(find.text('ウェーブを作成'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SHP-100'));
    await tester.tap(find.text('SHP-101'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'ウェーブを作成'));
    await tester.pumpAndSettle();

    expect(waveRepo.lastCreateShipmentPlanIds, [100, 101]);
    expect(find.text('WV-000001'), findsWidgets);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'three orders wanting the same parcel show as one stop on the sheet (§15, 0077)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final waveRepo = FakePickWaveRepository(waves: [_threeOrderWave()])
      ..sheet = _threeOrderSheet();
    final container = ProviderContainer(overrides: [
      ..._baseOverrides(),
      pickWaveRepositoryProvider.overrideWithValue(waveRepo),
    ]);
    addTearDown(container.dispose);
    await pumpAppWith(tester, container, const PickWaveSheetScreen(waveId: 1));

    expect(find.text('合計 30 点'), findsOneWidget);
    expect(find.text('R-01-A'), findsOneWidget);
    // One card, not three — this is the whole economics of a wave.
    expect(find.text('30'), findsOneWidget);
    expect(find.textContaining('L:L-B'), findsOneWidget);
    expect(find.text('3 件の出荷向け'), findsOneWidget);

    expect(find.text('不足分'), findsOneWidget);
    expect(find.text('5 点不足'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('an unassigned wave offers to take it; taking it starts picking',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final open = _threeOrderWave();
    final unassigned = PickWave(
      id: 1,
      code: open.code,
      warehouseId: open.warehouseId,
      status: PickWaveStatus.open,
      taskCount: open.taskCount,
      pickedCount: open.pickedCount,
      lists: open.lists,
    );
    final waveRepo = FakePickWaveRepository(waves: [unassigned])
      ..assignedToNameForAssign = 'ピッカー太郎';
    final container = ProviderContainer(overrides: [
      ..._baseOverrides(),
      pickWaveRepositoryProvider.overrideWithValue(waveRepo),
    ]);
    addTearDown(container.dispose);
    await pumpAppWith(tester, container, const PickWaveDetailScreen(waveId: 1));

    expect(find.text('未担当'), findsOneWidget);
    await tester.tap(find.text('自分が担当する'));
    await tester.pumpAndSettle();

    expect(waveRepo.lastAssignedUserId, 'user-1');
    expect(find.text('ピッカー太郎'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('completing is refused while any line is still unpicked',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final waveRepo = FakePickWaveRepository(waves: [_threeOrderWave()]);
    final container = ProviderContainer(overrides: [
      ..._baseOverrides(),
      pickWaveRepositoryProvider.overrideWithValue(waveRepo),
    ]);
    addTearDown(container.dispose);
    await pumpAppWith(tester, container, const PickWaveDetailScreen(waveId: 1));

    expect(find.text('未ピックの明細が残っています'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(button.onPressed, isNull);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('cancelling releases the wave and reports the release',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final waveRepo = FakePickWaveRepository(waves: [_threeOrderWave()]);
    final container = ProviderContainer(overrides: [
      ..._baseOverrides(),
      pickWaveRepositoryProvider.overrideWithValue(waveRepo),
    ]);
    addTearDown(container.dispose);
    await pumpAppWith(tester, container, const PickWaveDetailScreen(waveId: 1));

    await tester.tap(find.text('ウェーブを取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'ウェーブを取消')));
    await tester.pumpAndSettle();

    expect(find.text('取消'), findsWidgets);

    await tester.binding.setSurfaceSize(null);
  });
}

List<Override> _baseOverrides() => [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(
          const AuthUser(id: 'user-1', email: 'a@b.test', name: 'ピッカー太郎'))),
    ];
