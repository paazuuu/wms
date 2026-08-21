import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/product.dart';

/// Single mapping from a product's stock state to a [StatusTone] + label + icon,
/// so the list and detail screens render stock status identically.
class ProductStockUi {
  const ProductStockUi._(this.tone, this.label, this.icon);

  final StatusTone tone;
  final String label;
  final IconData icon;

  factory ProductStockUi.of(AppLocalizations l10n, Product product) {
    if (product.isOutOfStock || product.displayStock <= 0) {
      return ProductStockUi._(StatusTone.danger, l10n.stockOut,
          Icons.remove_shopping_cart_outlined);
    }
    if (product.isLowStock) {
      return ProductStockUi._(
          StatusTone.warning, l10n.stockLow, Icons.trending_down);
    }
    return ProductStockUi._(
        StatusTone.success, l10n.stockIn, Icons.inventory_2_outlined);
  }
}
