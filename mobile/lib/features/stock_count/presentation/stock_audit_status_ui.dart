import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../domain/stock_audit.dart';

/// Single mapping from a stock count's status to a [StatusTone] + icon + label,
/// so the list and detail screens render it identically.
class StockAuditStatusUi {
  const StockAuditStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static StockAuditStatusUi of(StockAudit audit) => switch (audit.status) {
        StockAuditStatus.draft => const StockAuditStatusUi(
            StatusTone.neutral, Icons.edit_note_outlined, 'Draft'),
        StockAuditStatus.inProgress => const StockAuditStatusUi(
            StatusTone.info, Icons.pending_actions_outlined, 'In progress'),
        StockAuditStatus.completed => const StockAuditStatusUi(
            StatusTone.success, Icons.check_circle_outline, 'Completed'),
        StockAuditStatus.cancelled => const StockAuditStatusUi(
            StatusTone.danger, Icons.cancel_outlined, 'Cancelled'),
      };
}
