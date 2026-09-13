import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/home/application/dashboard_providers.dart';
import 'package:wms_mobile/features/home/domain/dashboard_metrics.dart';
import 'package:wms_mobile/features/home/presentation/dashboard_widgets.dart';

import '../../support/harness.dart';

const _metrics = DashboardMetrics(
  asOf: '2026-09-10',
  inboundTodayUnits: 0,
  inboundTodayEvents: 0,
  outboundTodayUnits: 0,
  outboundTodayEvents: 0,
  outstandingPlanCount: 0,
  outstandingUnits: 0,
  totalSkus: 0,
  totalOnHand: 0,
  lowStockCount: 0,
  lowThreshold: 10,
  pendingInspectionCount: 4,
  openPickingCount: 3,
  packingWaitCount: 2,
  shippingWaitCount: 1,
  openCountCount: 0,
  openTransferCount: 5,
  putawayPendingCount: 6,
  trend: [],
  outstandingList: [],
  lowStockList: [],
);

void main() {
  testWidgets('shows a live count per task, including zero', (tester) async {
    // Wide enough that every tile of the horizontal strip is laid out; the
    // ListView builds lazily, so a narrow surface would hide the last ones.
    await tester.binding.setSurfaceSize(const Size(1200, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      Scaffold(
        body: TodayTasksRow(onOpenFeature: (_) {}),
      ),
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(FakeDashboardRepository(_metrics)),
      ],
    );

    expect(find.text('4'), findsOneWidget); // 検品待ち
    expect(find.text('6'), findsOneWidget); // 棚入れ待ち
    expect(find.text('3'), findsOneWidget); // ピッキング
    expect(find.text('2'), findsOneWidget); // 梱包待ち
    expect(find.text('1'), findsOneWidget); // 出荷待ち
    // 棚卸 is zero — still shown, not hidden.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('5'), findsOneWidget); // 倉庫間移動
  });

  testWidgets('tapping a tile reports its feature id', (tester) async {
    String? tapped;

    await pumpApp(
      tester,
      Scaffold(
        body: TodayTasksRow(onOpenFeature: (id) => tapped = id),
      ),
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(FakeDashboardRepository(_metrics)),
      ],
    );

    await tester.tap(find.text('ピッキング'));
    await tester.pumpAndSettle();

    expect(tapped, 'picking');
  });
}
