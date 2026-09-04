import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/delivery_plan_status.dart';
import '../domain/reconciliation.dart';

/// Maps a delivery plan's lifecycle status to a tone + icon + label.
class DeliveryPlanStatusUi {
  const DeliveryPlanStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static DeliveryPlanStatusUi of(
          AppLocalizations l10n, DeliveryPlanStatus status) =>
      switch (status) {
        DeliveryPlanStatus.open => DeliveryPlanStatusUi(
            StatusTone.info, Icons.inventory_2_outlined, l10n.deliveryStatusOpen),
        DeliveryPlanStatus.reconciling => DeliveryPlanStatusUi(
            StatusTone.warning,
            Icons.fact_check_outlined,
            l10n.deliveryStatusReconciling),
        DeliveryPlanStatus.partial => DeliveryPlanStatusUi(
            StatusTone.warning,
            Icons.incomplete_circle,
            l10n.deliveryStatusPartial),
        DeliveryPlanStatus.completed => DeliveryPlanStatusUi(
            StatusTone.success, Icons.check_circle, l10n.deliveryStatusCompleted),
      };
}

/// Maps a per-line reconciliation outcome to a tone + icon + label, shared by
/// the reconciliation list rows and the summary chips.
class ReconLineStatusUi {
  const ReconLineStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static ReconLineStatusUi of(AppLocalizations l10n, ReconLineStatus status) =>
      switch (status) {
        ReconLineStatus.pending => ReconLineStatusUi(
            StatusTone.neutral, Icons.hourglass_empty, l10n.reconPending),
        ReconLineStatus.matched => ReconLineStatusUi(
            StatusTone.success, Icons.check_circle_outline, l10n.reconMatched),
        ReconLineStatus.shortfall => ReconLineStatusUi(
            StatusTone.warning, Icons.trending_down, l10n.reconShortfall),
        ReconLineStatus.over => ReconLineStatusUi(
            StatusTone.danger, Icons.trending_up, l10n.reconOver),
        ReconLineStatus.unexpected => ReconLineStatusUi(
            StatusTone.danger, Icons.help_outline, l10n.reconUnexpected),
      };
}
