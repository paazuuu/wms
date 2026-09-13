import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/home/application/dashboard_providers.dart';
import 'package:wms_mobile/features/home/domain/dashboard_metrics.dart';
import 'package:wms_mobile/features/home/presentation/dashboard_widgets.dart';

import '../../support/harness.dart';

DashboardMetrics _metrics({
  int failedInspectionCount = 0,
  int outstandingPlanCount = 0,
  int putawayPendingCount = 0,
  int openPickingCount = 0,
}) =>
    DashboardMetrics(
      asOf: '2026-09-13',
      inboundTodayUnits: 0,
      inboundTodayEvents: 0,
      outboundTodayUnits: 0,
      outboundTodayEvents: 0,
      outstandingPlanCount: outstandingPlanCount,
      outstandingUnits: 0,
      totalSkus: 0,
      totalOnHand: 0,
      lowStockCount: 0,
      lowThreshold: 10,
      failedInspectionCount: failedInspectionCount,
      putawayPendingCount: putawayPendingCount,
      openPickingCount: openPickingCount,
      trend: const [],
      outstandingList: const [],
      lowStockList: const [],
    );

void main() {
  testWidgets('an all-clear state is shown explicitly, not an empty widget',
      (tester) async {
    await pumpApp(
      tester,
      Scaffold(body: DashboardNotificationsPanel(onOpenFeature: (_) {})),
      overrides: [
        dashboardRepositoryProvider
            .overrideWithValue(FakeDashboardRepository(_metrics())),
      ],
    );

    expect(find.text('対応が必要な通知はありません'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('lists only what needs attention, each with its count',
      (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: DashboardNotificationsPanel(onOpenFeature: (_) {}),
      ),
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(FakeDashboardRepository(
            _metrics(failedInspectionCount: 2, openPickingCount: 18))),
      ],
    );

    expect(find.text('検品NG'), findsOneWidget);
    expect(find.text('2 件'), findsOneWidget);
    expect(find.text('ピック待ち'), findsOneWidget);
    expect(find.text('18 件'), findsOneWidget);
    // Nothing pending for these — not listed as a zero row.
    expect(find.text('入荷待ち'), findsNothing);
    expect(find.text('棚入れ待ち'), findsNothing);
    expect(find.text('対応が必要な通知はありません'), findsNothing);
  });

  testWidgets('tapping a row opens the feature it names', (tester) async {
    String? opened;

    await pumpApp(
      tester,
      Scaffold(
        body: DashboardNotificationsPanel(onOpenFeature: (id) => opened = id),
      ),
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(FakeDashboardRepository(
            _metrics(failedInspectionCount: 2))),
      ],
    );

    await tester.tap(find.text('検品NG'));
    await tester.pumpAndSettle();

    expect(opened, 'inspection');
  });
}
