import 'package:equatable/equatable.dart';

import 'adjustment_type.dart';

/// A recorded stock adjustment returned by the backend after a change is
/// booked. `adjustmentQuantity` is signed: positive added stock, negative
/// removed it. `quantityAfter` is the resulting on-hand total.
class StockAdjustment extends Equatable {
  const StockAdjustment({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.adjustmentQuantity,
    this.reason,
    this.notes,
    this.productName,
    this.createdAt,
  });

  final int id;
  final int productId;
  final AdjustmentType type;
  final int quantityBefore;
  final int quantityAfter;
  final int adjustmentQuantity;
  final String? reason;
  final String? notes;
  final String? productName;
  final String? createdAt;

  bool get isIncrease => adjustmentQuantity >= 0;

  factory StockAdjustment.fromJson(Map<String, dynamic> json) {
    return StockAdjustment(
      id: _asInt(json['id']) ?? 0,
      productId: _asInt(json['product_id']) ?? 0,
      type: AdjustmentType.fromWire(json['type'] as String?),
      quantityBefore: _asInt(json['quantity_before']) ?? 0,
      quantityAfter: _asInt(json['quantity_after']) ?? 0,
      adjustmentQuantity: _asInt(json['adjustment_quantity']) ?? 0,
      reason: json['reason'] as String?,
      notes: json['notes'] as String?,
      productName: _nestedName(json['product']),
      createdAt: json['created_at'] as String?,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static String? _nestedName(dynamic value) {
    if (value is Map<String, dynamic>) return value['name'] as String?;
    return null;
  }

  @override
  List<Object?> get props =>
      [id, productId, type, quantityBefore, quantityAfter, adjustmentQuantity];
}
