import 'package:equatable/equatable.dart';

/// A single line on a purchase order, with ordered vs. received quantities.
class PurchaseOrderItem extends Equatable {
  const PurchaseOrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.remainingQuantity,
    this.isFullyReceived = false,
  });

  final int id;
  final int? productId;
  final String productName;
  final String sku;
  final int quantityOrdered;
  final int quantityReceived;
  final int remainingQuantity;
  final bool isFullyReceived;

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      id: json['id'] as int,
      productId: _asInt(json['product_id']),
      productName: json['product_name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      quantityOrdered: _asInt(json['quantity_ordered']) ?? 0,
      quantityReceived: _asInt(json['quantity_received']) ?? 0,
      remainingQuantity: _asInt(json['remaining_quantity']) ?? 0,
      isFullyReceived: json['is_fully_received'] as bool? ?? false,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  @override
  List<Object?> get props =>
      [id, quantityOrdered, quantityReceived, remainingQuantity];
}
