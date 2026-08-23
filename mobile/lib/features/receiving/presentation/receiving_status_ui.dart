import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/purchase_order.dart';

/// Single mapping from a purchase order's status to a [StatusTone] + label +
/// icon, so the receiving list and detail screens stay visually consistent.
class ReceivingStatusUi {
  const ReceivingStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static ReceivingStatusUi of(AppLocalizations l10n, PurchaseOrder order) {
    final fallback = _byStatus(l10n, order.status);
    // Prefer the backend-provided label when present; keep the derived tone/icon.
    final label = order.statusLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return ReceivingStatusUi(fallback.tone, fallback.icon, label);
    }
    return fallback;
  }

  static ReceivingStatusUi _byStatus(
          AppLocalizations l10n, PurchaseOrderStatus status) =>
      switch (status) {
        PurchaseOrderStatus.draft =>
          ReceivingStatusUi(StatusTone.neutral, Icons.edit_note, l10n.statusDraft),
        PurchaseOrderStatus.sent => ReceivingStatusUi(
            StatusTone.info, Icons.outbox_outlined, l10n.poSent),
        PurchaseOrderStatus.partial => ReceivingStatusUi(StatusTone.warning,
            Icons.incomplete_circle, l10n.poPartiallyReceived),
        PurchaseOrderStatus.received => ReceivingStatusUi(
            StatusTone.success, Icons.check_circle, l10n.poReceived),
        PurchaseOrderStatus.cancelled => ReceivingStatusUi(
            StatusTone.danger, Icons.cancel, l10n.statusCancelled),
      };
}
