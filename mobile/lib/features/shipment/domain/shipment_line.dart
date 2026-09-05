import 'package:equatable/equatable.dart';

/// One line on a shipment (出庫明細): a JAN and the quantity to ship.
class ShipmentLine extends Equatable {
  const ShipmentLine({
    required this.id,
    required this.janCode,
    required this.quantity,
    this.productCode,
    this.productName = '',
    this.spec,
    this.unitPrice,
    this.amount,
  });

  final int id;
  final String janCode;
  final int quantity;
  final String? productCode;
  final String productName;
  final String? spec;
  final int? unitPrice;
  final int? amount;

  factory ShipmentLine.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v');
    }

    return ShipmentLine(
      id: asInt(json['id']) ?? 0,
      janCode: (json['jan_code'] ?? '').toString(),
      quantity: asInt(json['quantity']) ?? 0,
      productCode: json['product_code']?.toString(),
      productName: json['product_name'] as String? ?? '',
      spec: json['spec'] as String?,
      unitPrice: asInt(json['unit_price']),
      amount: asInt(json['amount']),
    );
  }

  @override
  List<Object?> get props => [id, janCode, quantity];
}
