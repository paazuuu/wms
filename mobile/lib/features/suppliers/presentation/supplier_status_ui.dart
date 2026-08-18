import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../domain/supplier.dart';

/// Single mapping from a supplier's active state to a [StatusTone] + icon, so
/// the list and detail screens render it identically.
class SupplierStatusUi {
  const SupplierStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static SupplierStatusUi of(Supplier supplier) => supplier.isActive
      ? const SupplierStatusUi(
          StatusTone.success, Icons.local_shipping, 'Active')
      : const SupplierStatusUi(
          StatusTone.neutral, Icons.block_outlined, 'Inactive');
}
