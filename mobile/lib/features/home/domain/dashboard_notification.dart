import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import 'dashboard_metrics.dart';

/// One row of the dashboard's alert list (UI spec §30):
///
/// ```
/// 🔴 検品NG 2      🟠 入荷待ち 12
/// 🟡 棚入れ待ち 7   🔵 ピック待ち 18
/// クリックで該当業務へ直接移動。
/// ```
///
/// Named the "notifications" list to match the spec chapter, even though the
/// existing dashboard already used the mockup's own Japanese heading ("今日の
/// 作業") for the always-visible task-count strip ([TodayTasksRow]) — reusing
/// that heading here would put two differently-shaped sections under the same
/// label. This list is deliberately narrower than that strip: it surfaces
/// only what is actually calling for attention (count > 0), colour-coded by
/// how urgent it is, rather than repeating every work count a second time in
/// a different shape.
class DashboardNotification {
  const DashboardNotification({
    required this.tone,
    required this.icon,
    required this.label,
    required this.count,
    required this.featureId,
  });

  final StatusTone tone;
  final IconData icon;
  final String label;
  final int count;

  /// Feature-catalog id to open on tap ("クリックで該当業務へ直接移動").
  final String featureId;
}

/// Builds §30's alert list from metrics already computed by
/// `dashboard_metrics` (0041 added the one new field this needed —
/// [DashboardMetrics.failedInspectionCount]). Rows with nothing to report are
/// left out entirely; an empty result means "nothing needs attention", which
/// the caller renders as an explicit all-clear state rather than an absence.
List<DashboardNotification> dashboardNotifications(
  AppLocalizations l10n,
  DashboardMetrics metrics,
) {
  final all = [
    // 🔴 検品NG — an actual failure, the one alert that is a problem rather
    // than a queue to work through, so it leads and reads as danger.
    DashboardNotification(
      tone: StatusTone.danger,
      icon: Icons.error_outline,
      label: l10n.notifFailedInspection,
      count: metrics.failedInspectionCount,
      featureId: 'inspection',
    ),
    // 🟠 入荷待ち
    DashboardNotification(
      tone: StatusTone.warning,
      icon: Icons.local_shipping_outlined,
      label: l10n.notifOutstandingPlans,
      count: metrics.outstandingPlanCount,
      featureId: 'delivery',
    ),
    // 🟡 棚入れ待ち — its own row distinct from 入荷待ち even though both use
    // the warning tone: the label and icon carry the distinction (status
    // must never rely on colour alone), and put-away only ever appears for a
    // warehouse that uses locations, so it is legitimately less common.
    DashboardNotification(
      tone: StatusTone.warning,
      icon: Icons.move_to_inbox_outlined,
      label: l10n.notifPutawayPending,
      count: metrics.putawayPendingCount,
      featureId: 'putaway',
    ),
    // 🔵 ピック待ち
    DashboardNotification(
      tone: StatusTone.info,
      icon: Icons.shopping_cart_checkout_outlined,
      label: l10n.notifOpenPicking,
      count: metrics.openPickingCount,
      featureId: 'picking',
    ),
  ];
  return all.where((n) => n.count > 0).toList();
}
