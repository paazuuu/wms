import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/work_order.dart';

/// Single mapping from a work order's status to a [StatusTone] + icon + label,
/// so the list and detail screens render it identically.
class WorkOrderStatusUi {
  const WorkOrderStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static WorkOrderStatusUi of(AppLocalizations l10n, WorkOrder order) =>
      switch (order.status) {
        WorkOrderStatus.draft => WorkOrderStatusUi(
            StatusTone.neutral, Icons.edit_note_outlined, l10n.statusDraft),
        WorkOrderStatus.pending => WorkOrderStatusUi(
            StatusTone.info, Icons.schedule_outlined, l10n.statusPending),
        WorkOrderStatus.inProgress => WorkOrderStatusUi(StatusTone.warning,
            Icons.precision_manufacturing_outlined, l10n.statusInProgress),
        WorkOrderStatus.completed => WorkOrderStatusUi(
            StatusTone.success, Icons.check_circle_outline, l10n.statusCompleted),
        WorkOrderStatus.cancelled => WorkOrderStatusUi(
            StatusTone.danger, Icons.cancel_outlined, l10n.statusCancelled),
      };
}
