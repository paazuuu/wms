import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/purchase_order.dart';

class PurchaseOrderStatusUi {
  const PurchaseOrderStatusUi(this.label, this.icon, this.tone);

  final String label;
  final IconData icon;
  final StatusTone tone;

  static PurchaseOrderStatusUi of(AppLocalizations l10n, PurchaseOrderStatus status) =>
      switch (status) {
        PurchaseOrderStatus.draft =>
          PurchaseOrderStatusUi(l10n.poStatusDraft, Icons.edit_note, StatusTone.neutral),
        PurchaseOrderStatus.submitted => PurchaseOrderStatusUi(
            l10n.poStatusSubmitted, Icons.hourglass_empty, StatusTone.warning),
        PurchaseOrderStatus.approved => PurchaseOrderStatusUi(
            l10n.poStatusApproved, Icons.check_circle_outline, StatusTone.info),
        PurchaseOrderStatus.rejected =>
          PurchaseOrderStatusUi(l10n.poStatusRejected, Icons.block, StatusTone.danger),
        PurchaseOrderStatus.cancelled =>
          PurchaseOrderStatusUi(l10n.poStatusCancelled, Icons.block, StatusTone.neutral),
        PurchaseOrderStatus.completed =>
          PurchaseOrderStatusUi(l10n.poStatusCompleted, Icons.task_alt, StatusTone.success),
      };
}
