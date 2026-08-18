import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../domain/warehouse.dart';

/// Single mapping from a warehouse's active state to a [StatusTone] + icon, so
/// the list and detail screens render it identically.
class WarehouseStatusUi {
  const WarehouseStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static WarehouseStatusUi of(Warehouse warehouse) => warehouse.isActive
      ? const WarehouseStatusUi(StatusTone.success, Icons.warehouse, 'Active')
      : const WarehouseStatusUi(
          StatusTone.neutral, Icons.warehouse_outlined, 'Inactive');
}
