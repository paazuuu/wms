import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/work_order.dart';

class WorkOrderStatusUi {
  const WorkOrderStatusUi(this.label, this.icon, this.tone);

  final String label;
  final IconData icon;
  final StatusTone tone;

  static WorkOrderStatusUi of(AppLocalizations l10n, WorkOrderStatus status) =>
      switch (status) {
        WorkOrderStatus.draft =>
          WorkOrderStatusUi(l10n.woStatusDraft, Icons.edit_note, StatusTone.neutral),
        WorkOrderStatus.inProgress => WorkOrderStatusUi(
            l10n.woStatusInProgress, Icons.precision_manufacturing_outlined, StatusTone.info),
        WorkOrderStatus.completed =>
          WorkOrderStatusUi(l10n.woStatusCompleted, Icons.task_alt, StatusTone.success),
        WorkOrderStatus.cancelled =>
          WorkOrderStatusUi(l10n.woStatusCancelled, Icons.block, StatusTone.neutral),
      };
}
