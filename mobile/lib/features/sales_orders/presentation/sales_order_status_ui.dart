import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/sales_order.dart';

/// Single mapping from a sales order's status to a [StatusTone] + icon + label,
/// so the list and detail screens render it identically.
class SalesOrderStatusUi {
  const SalesOrderStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static SalesOrderStatusUi of(AppLocalizations l10n, SalesOrder order) =>
      switch (order.status) {
        SalesOrderStatus.pending => SalesOrderStatusUi(
            StatusTone.neutral, Icons.schedule_outlined, l10n.statusPending),
        SalesOrderStatus.processing => SalesOrderStatusUi(
            StatusTone.info, Icons.inventory_outlined, l10n.salesProcessing),
        SalesOrderStatus.shipped => SalesOrderStatusUi(StatusTone.warning,
            Icons.local_shipping_outlined, l10n.salesShipped),
        SalesOrderStatus.delivered => SalesOrderStatusUi(
            StatusTone.success, Icons.check_circle_outline, l10n.salesDelivered),
        SalesOrderStatus.cancelled => SalesOrderStatusUi(
            StatusTone.danger, Icons.cancel_outlined, l10n.statusCancelled),
      };
}
