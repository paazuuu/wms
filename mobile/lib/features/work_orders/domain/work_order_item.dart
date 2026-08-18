import 'package:equatable/equatable.dart';

/// A single component line of a work order: how much of a component product the
/// assembly requires and how much has already been consumed.
class WorkOrderItem extends Equatable {
  const WorkOrderItem({
    required this.id,
    required this.productId,
    this.productName = '',
    this.sku = '',
    this.quantityRequired = 0,
    this.quantityConsumed = 0,
    this.stock,
  });

  final int id;
  final int productId;
  final String productName;
  final String sku;
  final double quantityRequired;
  final double quantityConsumed;
  final int? stock;

  double get quantityRemaining {
    final remaining = quantityRequired - quantityConsumed;
    return remaining > 0 ? remaining : 0;
  }

  factory WorkOrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    return WorkOrderItem(
      id: json['id'] as int,
      productId: _asInt(json['product_id']) ?? 0,
      productName: product is Map<String, dynamic>
          ? (product['name'] as String? ?? '')
          : '',
      sku: product is Map<String, dynamic>
          ? (product['sku'] as String? ?? '')
          : '',
      quantityRequired: _asDouble(json['quantity_required']),
      quantityConsumed: _asDouble(json['quantity_consumed']),
      stock: product is Map<String, dynamic> ? _asInt(product['stock']) : null,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  @override
  List<Object?> get props =>
      [id, productId, quantityRequired, quantityConsumed];
}

/// Renders a possibly-fractional quantity without a trailing `.0` for wholes.
String formatQuantity(double value) {
  if (value == value.roundToDouble()) return '${value.toInt()}';
  return value.toString();
}
