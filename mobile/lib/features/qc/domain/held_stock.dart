import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

int? _asIntOrNull(dynamic v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

String? _asText(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// One parcel sitting in QC_PENDING: on hand, and not shippable until an
/// inspection says so (§13, `qc_pending_stock` in 0068).
///
/// The point of the screen this feeds is that held stock is *invisible* in the
/// numbers people usually look at — it counts toward on-hand and not toward
/// available, so a product can read "100 in stock" and ship nothing. This is the
/// list that explains why.
class HeldStock extends Equatable {
  const HeldStock({
    required this.productId,
    required this.warehouseId,
    required this.quantity,
    this.janCode,
    this.productName,
    this.lotId,
    this.lotCode,
    this.expiry,
    this.serialId,
    this.serialNumber,
    this.statusCode = 'QC_PENDING',
    this.receivedAt,
  });

  final int productId;
  final int warehouseId;
  final int quantity;
  final String? janCode;
  final String? productName;
  final int? lotId;
  final String? lotCode;
  final DateTime? expiry;
  final int? serialId;
  final String? serialNumber;
  final String statusCode;

  /// When this parcel arrived, from the receipt items behind it. The step from
  /// "this is held" to "who sent it" is one tap because of this field.
  final DateTime? receivedAt;

  bool get isExpired => expiry != null && expiry!.isBefore(DateTime.now());

  /// How long it has been sitting on the dock. The number that turns a queue
  /// into a priority: a parcel held for a week is a different problem to one
  /// held for an hour.
  int? get daysHeld => receivedAt == null
      ? null
      : DateTime.now().difference(receivedAt!).inDays;

  factory HeldStock.fromJson(Map<String, dynamic> json) => HeldStock(
        productId: _asInt(json['product_id']),
        warehouseId: _asInt(json['warehouse_id']),
        quantity: _asInt(json['quantity']),
        janCode: _asText(json['jan_code']),
        productName: _asText(json['product_name']),
        lotId: _asIntOrNull(json['lot_id']),
        lotCode: _asText(json['lot_code']),
        expiry: DateTime.tryParse('${json['expiry']}'),
        serialId: _asIntOrNull(json['serial_id']),
        serialNumber: _asText(json['serial_number']),
        statusCode: _asText(json['status_code']) ?? 'QC_PENDING',
        receivedAt: DateTime.tryParse('${json['received_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props => [
        productId,
        warehouseId,
        quantity,
        lotId,
        serialId,
        statusCode,
        expiry,
      ];
}
