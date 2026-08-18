import 'package:equatable/equatable.dart';

/// A single line on a sales order.
class SalesOrderItem extends Equatable {
  const SalesOrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.sku,
    this.quantity = 0,
    this.unitPrice,
    this.total,
  });

  final int id;
  final int productId;
  final String productName;
  final String? sku;
  final int quantity;
  final String? unitPrice;
  final String? total;

  factory SalesOrderItem.fromJson(Map<String, dynamic> json) {
    return SalesOrderItem(
      id: json['id'] as int,
      productId: _asInt(json['product_id']) ?? 0,
      productName: json['product_name'] as String? ?? '',
      sku: json['sku'] as String?,
      quantity: _asInt(json['quantity']) ?? 0,
      unitPrice: _asString(json['unit_price']),
      total: _asString(json['total']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static String? _asString(dynamic value) => value?.toString();

  @override
  List<Object?> get props => [id, productId, quantity, total];
}
