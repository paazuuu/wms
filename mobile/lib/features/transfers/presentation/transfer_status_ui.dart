import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/transfer_order.dart';

class TransferStatusUi {
  const TransferStatusUi(this.label, this.icon, this.tone);

  final String label;
  final IconData icon;
  final StatusTone tone;

  static TransferStatusUi of(AppLocalizations l10n, TransferStatus status) =>
      switch (status) {
        TransferStatus.draft =>
          TransferStatusUi(l10n.transferStatusDraft, Icons.edit_note, StatusTone.neutral),
        TransferStatus.pendingApproval => TransferStatusUi(
            l10n.transferStatusPendingApproval, Icons.hourglass_empty, StatusTone.warning),
        TransferStatus.approved => TransferStatusUi(
            l10n.transferStatusApproved, Icons.check_circle_outline, StatusTone.info),
        TransferStatus.picking => TransferStatusUi(l10n.transferStatusPicking,
            Icons.shopping_cart_checkout_outlined, StatusTone.info),
        TransferStatus.inTransit => TransferStatusUi(
            l10n.transferStatusInTransit, Icons.local_shipping_outlined, StatusTone.info),
        TransferStatus.receiving => TransferStatusUi(l10n.transferStatusReceiving,
            Icons.move_to_inbox_outlined, StatusTone.warning),
        TransferStatus.completed => TransferStatusUi(
            l10n.transferStatusCompleted, Icons.task_alt, StatusTone.success),
        TransferStatus.rejected =>
          TransferStatusUi(l10n.transferStatusRejected, Icons.block, StatusTone.danger),
        TransferStatus.cancelled =>
          TransferStatusUi(l10n.transferStatusCancelled, Icons.block, StatusTone.neutral),
      };
}
