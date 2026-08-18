import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../domain/product.dart';

/// Single mapping from a product's stock state to a [StatusTone] + label + icon,
/// so the list and detail screens render stock status identically.
class ProductStockUi {
  const ProductStockUi._(this.tone, this.label, this.icon);

  final StatusTone tone;
  final String label;
  final IconData icon;

  factory ProductStockUi.of(Product product) {
    if (product.isOutOfStock || product.displayStock <= 0) {
      return const ProductStockUi._(
          StatusTone.danger, 'Out of stock', Icons.remove_shopping_cart_outlined);
    }
    if (product.isLowStock) {
      return const ProductStockUi._(
          StatusTone.warning, 'Low stock', Icons.trending_down);
    }
    return const ProductStockUi._(
        StatusTone.success, 'In stock', Icons.inventory_2_outlined);
  }
}
