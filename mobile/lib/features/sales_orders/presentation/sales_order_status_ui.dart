import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../domain/sales_order.dart';

/// Single mapping from a sales order's status to a [StatusTone] + icon + label,
/// so the list and detail screens render it identically.
class SalesOrderStatusUi {
  const SalesOrderStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static SalesOrderStatusUi of(SalesOrder order) => switch (order.status) {
        SalesOrderStatus.pending => const SalesOrderStatusUi(
            StatusTone.neutral, Icons.schedule_outlined, 'Pending'),
        SalesOrderStatus.processing => const SalesOrderStatusUi(
            StatusTone.info, Icons.inventory_outlined, 'Processing'),
        SalesOrderStatus.shipped => const SalesOrderStatusUi(
            StatusTone.warning, Icons.local_shipping_outlined, 'Shipped'),
        SalesOrderStatus.delivered => const SalesOrderStatusUi(
            StatusTone.success, Icons.check_circle_outline, 'Delivered'),
        SalesOrderStatus.cancelled => const SalesOrderStatusUi(
            StatusTone.danger, Icons.cancel_outlined, 'Cancelled'),
      };
}
