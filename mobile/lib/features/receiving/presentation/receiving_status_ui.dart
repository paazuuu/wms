import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../domain/purchase_order.dart';

/// Single mapping from a purchase order's status to a [StatusTone] + label +
/// icon, so the receiving list and detail screens stay visually consistent.
class ReceivingStatusUi {
  const ReceivingStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static ReceivingStatusUi of(PurchaseOrder order) {
    final fallback = _byStatus(order.status);
    // Prefer the backend-provided label when present; keep the derived tone/icon.
    final label = order.statusLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return ReceivingStatusUi(fallback.tone, fallback.icon, label);
    }
    return fallback;
  }

  static ReceivingStatusUi _byStatus(PurchaseOrderStatus status) =>
      switch (status) {
        PurchaseOrderStatus.draft => const ReceivingStatusUi(
            StatusTone.neutral, Icons.edit_note, 'Draft'),
        PurchaseOrderStatus.sent => const ReceivingStatusUi(
            StatusTone.info, Icons.outbox_outlined, 'Sent'),
        PurchaseOrderStatus.partial => const ReceivingStatusUi(
            StatusTone.warning, Icons.incomplete_circle, 'Partially received'),
        PurchaseOrderStatus.received => const ReceivingStatusUi(
            StatusTone.success, Icons.check_circle, 'Received'),
        PurchaseOrderStatus.cancelled => const ReceivingStatusUi(
            StatusTone.danger, Icons.cancel, 'Cancelled'),
      };
}
