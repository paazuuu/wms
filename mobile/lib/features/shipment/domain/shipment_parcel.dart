import 'package:equatable/equatable.dart';

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

/// One parcel that left the building on this shipment (0075) — the read a
/// recall starts from: which lots went to this customer, and when. A
/// SHIP_CANCEL row is a reversal, not noise: it carries the opposite sign and
/// is shown as it happened, alongside what it reversed.
class ShipmentParcel extends Equatable {
  const ShipmentParcel({
    required this.movementId,
    required this.movementType,
    required this.janCode,
    required this.quantity,
    this.createdAt,
    this.productId,
    this.productName = '',
    this.lotId,
    this.lotCode,
    this.expiryDate,
    this.serialId,
    this.serialNumber,
    this.binId,
    this.binCode,
  });

  final int movementId;
  final String movementType;
  final String janCode;

  /// Positive: units this row took out. Negative on a SHIP_CANCEL row — the
  /// server's own sign, not derived here.
  final int quantity;

  final DateTime? createdAt;
  final int? productId;
  final String productName;
  final int? lotId;
  final String? lotCode;
  final String? expiryDate;
  final int? serialId;
  final String? serialNumber;
  final int? binId;
  final String? binCode;

  bool get isReversal => movementType == 'SHIP_CANCEL';

  factory ShipmentParcel.fromJson(Map<String, dynamic> json) => ShipmentParcel(
        movementId: _asIntOrNull(json['movement_id']) ?? 0,
        movementType: (json['movement_type'] ?? '').toString(),
        janCode: (json['jan_code'] ?? '').toString(),
        quantity: _asIntOrNull(json['quantity']) ?? 0,
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        productId: _asIntOrNull(json['product_id']),
        productName: json['product_name'] as String? ?? '',
        lotId: _asIntOrNull(json['lot_id']),
        lotCode: json['lot_code'] as String?,
        expiryDate: json['expiry_date'] as String?,
        serialId: _asIntOrNull(json['serial_id']),
        serialNumber: json['serial_number'] as String?,
        binId: _asIntOrNull(json['bin_id']),
        binCode: json['bin_code'] as String?,
      );

  @override
  List<Object?> get props =>
      [movementId, movementType, janCode, quantity, lotId, serialId];
}
