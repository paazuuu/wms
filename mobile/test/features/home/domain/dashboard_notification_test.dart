import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/ui/status_pill.dart';
import 'package:wms_mobile/features/home/domain/dashboard_metrics.dart';
import 'package:wms_mobile/features/home/domain/dashboard_notification.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

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
  final ja = lookupAppLocalizations(const Locale('ja'));

  group('dashboardNotifications (UI spec §30)', () {
    test('nothing pending means an empty list, not four zero rows', () {
      expect(dashboardNotifications(ja, _metrics()), isEmpty);
    });

    test('only rows with something to report are included', () {
      final alerts = dashboardNotifications(
        ja,
        _metrics(failedInspectionCount: 2, openPickingCount: 18),
      );

      expect(alerts.map((a) => a.featureId), ['inspection', 'picking']);
      expect(alerts.map((a) => a.count), [2, 18]);
    });

    test('検品NG leads and is coloured danger — a problem, not a queue', () {
      final alerts = dashboardNotifications(
        ja,
        _metrics(failedInspectionCount: 1, outstandingPlanCount: 1),
      );

      expect(alerts.first.featureId, 'inspection');
      expect(alerts.first.tone, StatusTone.danger);
      expect(alerts.first.label, '検品NG');
    });

    test('入荷待ち and 棚入れ待ち stay distinct rows despite sharing a tone', () {
      final alerts = dashboardNotifications(
        ja,
        _metrics(outstandingPlanCount: 12, putawayPendingCount: 7),
      );

      expect(alerts, hasLength(2));
      expect(alerts[0].tone, StatusTone.warning);
      expect(alerts[1].tone, StatusTone.warning);
      expect(alerts.map((a) => a.label), ['入荷待ち', '棚入れ待ち']);
      expect(alerts.map((a) => a.featureId), ['delivery', 'putaway']);
    });

    test('every alert names the feature id its tap should open', () {
      final alerts = dashboardNotifications(
        ja,
        _metrics(
          failedInspectionCount: 1,
          outstandingPlanCount: 1,
          putawayPendingCount: 1,
          openPickingCount: 1,
        ),
      );

      expect(alerts.map((a) => a.featureId),
          ['inspection', 'delivery', 'putaway', 'picking']);
    });
  });
}
