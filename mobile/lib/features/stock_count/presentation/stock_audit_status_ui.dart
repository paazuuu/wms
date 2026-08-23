import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_audit.dart';

/// Single mapping from a stock count's status to a [StatusTone] + icon + label,
/// so the list and detail screens render it identically.
class StockAuditStatusUi {
  const StockAuditStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static StockAuditStatusUi of(AppLocalizations l10n, StockAudit audit) =>
      switch (audit.status) {
        StockAuditStatus.draft => StockAuditStatusUi(
            StatusTone.neutral, Icons.edit_note_outlined, l10n.statusDraft),
        StockAuditStatus.inProgress => StockAuditStatusUi(StatusTone.info,
            Icons.pending_actions_outlined, l10n.statusInProgress),
        StockAuditStatus.completed => StockAuditStatusUi(
            StatusTone.success, Icons.check_circle_outline, l10n.statusCompleted),
        StockAuditStatus.cancelled => StockAuditStatusUi(
            StatusTone.danger, Icons.cancel_outlined, l10n.statusCancelled),
      };
}
