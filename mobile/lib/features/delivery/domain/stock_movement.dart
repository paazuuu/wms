import 'package:equatable/equatable.dart';

/// One entry of the stock ledger: why a quantity changed (spec §18).
///
/// The invariant the backend guarantees is `quantityBefore + quantity ==
/// quantityAfter`, so a row is self-describing without replaying the whole
/// history.
class StockMovement extends Equatable {
  const StockMovement({
    required this.id,
    required this.janCode,
    required this.movementType,
    required this.quantity,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.createdAt,
    this.productName = '',
    this.warehouseName = '',
    this.referenceType,
    this.referenceId,
    this.note,
  });

  final int id;
  final String janCode;
  final String productName;
  final String warehouseName;

  /// OPENING | RECEIPT | RECEIPT_CANCEL | PUTAWAY | PICK | SHIP | SHIP_CANCEL |
  /// ADJUST | COUNT | TRANSFER_IN | TRANSFER_OUT.
  final String movementType;

  /// Signed effective delta.
  final int quantity;
  final int quantityBefore;
  final int quantityAfter;

  /// What the movement was made against, e.g. `reconciliation` / `shipment_plan`.
  final String? referenceType;
  final String? referenceId;
  final String? note;
  final DateTime? createdAt;

  bool get isIncrease => quantity > 0;

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    return StockMovement(
      id: asInt(json['id']),
      janCode: (json['jan_code'] ?? '').toString(),
      productName: json['product_name'] as String? ?? '',
      warehouseName: json['warehouse_name'] as String? ?? '',
      movementType: json['movement_type'] as String? ?? '',
      quantity: asInt(json['quantity']),
      quantityBefore: asInt(json['quantity_before']),
      quantityAfter: asInt(json['quantity_after']),
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
    );
  }

  @override
  List<Object?> get props =>
      [id, janCode, movementType, quantity, quantityBefore, quantityAfter];
}
