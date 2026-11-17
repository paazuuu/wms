// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/home/application/dashboard_providers.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/home/domain/dashboard_metrics.dart';
import 'package:wms_mobile/features/home/presentation/dashboard_widgets.dart';

import 'package:wms_mobile/core/ui/responsive.dart';

import '../../support/harness.dart';

DashboardMetrics _metrics() => DashboardMetrics(
      asOf: '2026-09-09',
      inboundTodayUnits: 120,
      inboundTodayEvents: 2,
      outboundTodayUnits: 80,
      outboundTodayEvents: 1,
      outstandingPlanCount: 2,
      outstandingUnits: 17117,
      totalSkus: 5,
      totalOnHand: 900,
      lowStockCount: 1,
      lowThreshold: 10,
      trend: [
        TrendPoint(day: '2026-09-08', inbound: 40, outbound: 10),
        TrendPoint(day: '2026-09-09', inbound: 120, outbound: 80),
      ],
      outstandingList: [
        OutstandingPlanBrief(
            id: 1,
            deliveryNumber: '0901',
            supplierName: '新東光通商株式会社',
            outstanding: 135),
      ],
      lowStockList: [
        LowStockBrief(janCode: '4902505632037', productName: 'ペン', onHand: 3),
      ],
    );

void main() {
  testWidgets('dashboard scopes its query to the active warehouse',
      (tester) async {
    final repo = FakeDashboardRepository(_metrics());
    final container = ProviderContainer(overrides: [
      dashboardRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await pumpAppWith(
      tester,
      container,
      const Scaffold(
        body: SingleChildScrollView(child: DashboardMetricsSection()),
      ),
    );
    // No warehouse chosen => company-wide figures.
    expect(repo.lastWarehouseId, isNull);

    container.read(activeWarehouseIdProvider.notifier).state = 2;
    await tester.pumpAndSettle();
    expect(repo.lastWarehouseId, 2);
  });

  testWidgets('dashboard section shows KPI values, chart and watch lists',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    await pumpApp(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: DashboardMetricsSection(),
        ),
      ),
      overrides: [
        dashboardRepositoryProvider
            .overrideWithValue(FakeDashboardRepository(_metrics())),
      ],
    );

    // KPI figures (formatted with thousands separators).
    expect(find.text('17,117'), findsOneWidget); // outstanding units
    expect(find.text('120'), findsWidgets); // inbound today units
    expect(find.text('900'), findsOneWidget); // total on hand

    // Section titles.
    expect(find.text('入出庫の推移（14日）'), findsOneWidget);
    expect(find.text('未納リスト'), findsOneWidget);
    expect(find.text('在庫アラート'), findsOneWidget);

    // Worklist content.
    expect(find.text('0901'), findsOneWidget);
    expect(find.text('ペン'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
  testWidgets('a window the browser reports as nothing (a hidden tab, DevTools over it) is laid out at the smallest size, not at zero', (tester) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      const MinimumLayoutSize(
        child: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: DashboardMetricsSection(),
          ),
        ),
      ),
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(FakeDashboardRepository(_metrics())),
      ],
    );
    expect(find.text('17,117'), findsOneWidget);
    for (final s in const [Size(0, 0), Size(0, 900), Size(1200, 0), Size(1, 1)]) {
      tester.view.physicalSize = s;
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$s');
    }
    // Back to a real window: laid out exactly at it.
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump();
    expect(tester.getSize(find.byType(Scaffold)), const Size(1200, 900));
    expect(find.text('17,117'), findsOneWidget);
  });
}
