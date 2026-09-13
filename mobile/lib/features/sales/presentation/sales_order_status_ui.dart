import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/sales_order.dart';

class SalesOrderStatusUi {
  const SalesOrderStatusUi(this.label, this.icon, this.tone);

  final String label;
  final IconData icon;
  final StatusTone tone;

  static SalesOrderStatusUi of(AppLocalizations l10n, SalesOrderStatus status) =>
      switch (status) {
        SalesOrderStatus.draft =>
          SalesOrderStatusUi(l10n.soStatusDraft, Icons.edit_note, StatusTone.neutral),
        SalesOrderStatus.submitted => SalesOrderStatusUi(
            l10n.soStatusSubmitted, Icons.hourglass_empty, StatusTone.warning),
        SalesOrderStatus.approved => SalesOrderStatusUi(
            l10n.soStatusApproved, Icons.check_circle_outline, StatusTone.info),
        SalesOrderStatus.rejected =>
          SalesOrderStatusUi(l10n.soStatusRejected, Icons.block, StatusTone.danger),
        SalesOrderStatus.cancelled =>
          SalesOrderStatusUi(l10n.soStatusCancelled, Icons.block, StatusTone.neutral),
        SalesOrderStatus.completed =>
          SalesOrderStatusUi(l10n.soStatusCompleted, Icons.task_alt, StatusTone.success),
      };
}
