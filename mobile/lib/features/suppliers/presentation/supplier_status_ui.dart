import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/supplier.dart';

/// Single mapping from a supplier's active state to a [StatusTone] + icon, so
/// the list and detail screens render it identically.
class SupplierStatusUi {
  const SupplierStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static SupplierStatusUi of(AppLocalizations l10n, Supplier supplier) =>
      supplier.isActive
          ? SupplierStatusUi(
              StatusTone.success, Icons.local_shipping, l10n.statusActive)
          : SupplierStatusUi(
              StatusTone.neutral, Icons.block_outlined, l10n.statusInactive);
}
