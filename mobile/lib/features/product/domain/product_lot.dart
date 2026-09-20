import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

int? _asIntOrNull(dynamic v) => v == null
    ? null
    : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

String? _asText(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// One row of `product_lots` (0060): a lot of one product, with the dates and
/// the supplier it arrived from.
///
/// [daysToExpiry] is computed by the server against its own clock rather than by
/// the client against the device's, because a tablet with a wrong date must not
/// be able to hide an expired lot.
class ProductLot extends Equatable {
  const ProductLot({
    required this.id,
    required this.lotCode,
    this.expiryDate,
    this.manufactureDate,
    this.receivedAt,
    this.supplierId,
    this.supplierName,
    this.daysToExpiry,
    this.serialCount = 0,
    this.note,
  });

  final int id;
  final String lotCode;
  final DateTime? expiryDate;
  final DateTime? manufactureDate;
  final DateTime? receivedAt;
  final int? supplierId;
  final String? supplierName;
  final int? daysToExpiry;
  final int serialCount;
  final String? note;

  /// Already past its date. Distinct from "expiring soon" — an expired lot is a
  /// decision someone has to make, not a warning.
  bool get isExpired => daysToExpiry != null && daysToExpiry! < 0;

  bool expiresWithin(int days) =>
      daysToExpiry != null && daysToExpiry! >= 0 && daysToExpiry! <= days;

  factory ProductLot.fromJson(Map<String, dynamic> json) => ProductLot(
        id: _asInt(json['id'] ?? json['lot_id']),
        lotCode: (json['lot_code'] ?? '').toString(),
        expiryDate: DateTime.tryParse('${json['expiry_date']}'),
        manufactureDate: DateTime.tryParse('${json['manufacture_date']}'),
        receivedAt: DateTime.tryParse('${json['received_at']}')?.toLocal(),
        supplierId: _asIntOrNull(json['supplier_id']),
        supplierName: _asText(json['supplier_name']),
        daysToExpiry: _asIntOrNull(json['days_to_expiry']),
        serialCount: _asInt(json['serial_count'] ?? 0),
        note: _asText(json['note']),
      );

  @override
  List<Object?> get props =>
      [id, lotCode, expiryDate, manufactureDate, supplierId, serialCount];
}

/// One row of `product_serials` (0060): a single physical unit, and where it is
/// in its life.
class ProductSerial extends Equatable {
  const ProductSerial({
    required this.id,
    required this.serialNumber,
    required this.status,
    this.lotId,
    this.lotCode,
    this.createdAt,
    this.note,
  });

  final int id;
  final String serialNumber;

  /// IN_STOCK / SHIPPED / RETURNED / SCRAPPED / HOLD (0060). Kept as the code,
  /// not an enum, because the vocabulary lives in the database and a build that
  /// predates a new status should show it rather than refuse to parse the row.
  final String status;
  final int? lotId;
  final String? lotCode;
  final DateTime? createdAt;
  final String? note;

  bool get isInStock => status == 'IN_STOCK';

  factory ProductSerial.fromJson(Map<String, dynamic> json) => ProductSerial(
        id: _asInt(json['id']),
        serialNumber: (json['serial_number'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        lotId: _asIntOrNull(json['lot_id']),
        lotCode: _asText(json['lot_code']),
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        note: _asText(json['note']),
      );

  @override
  List<Object?> get props => [id, serialNumber, status, lotId, lotCode];
}

/// One lot that is running out of time, as `expiring_lots` returns it (0060):
/// the lot *and* the product, because the operator acting on this list is
/// looking for goods on a shelf, not for a lot code in the abstract.
class ExpiringLot extends Equatable {
  const ExpiringLot({
    required this.lotId,
    required this.lotCode,
    required this.productId,
    required this.productName,
    this.expiryDate,
    this.daysToExpiry,
    this.isExpired = false,
    this.janCode,
    this.sku,
    this.trackingMode,
    this.serialCount = 0,
  });

  final int lotId;
  final String lotCode;
  final int productId;
  final String productName;
  final DateTime? expiryDate;
  final int? daysToExpiry;
  final bool isExpired;
  final String? janCode;
  final String? sku;
  final String? trackingMode;
  final int serialCount;

  factory ExpiringLot.fromJson(Map<String, dynamic> json) => ExpiringLot(
        lotId: _asInt(json['lot_id']),
        lotCode: (json['lot_code'] ?? '').toString(),
        productId: _asInt(json['product_id']),
        productName: (json['product_name'] ?? '').toString(),
        expiryDate: DateTime.tryParse('${json['expiry_date']}'),
        daysToExpiry: _asIntOrNull(json['days_to_expiry']),
        isExpired: json['is_expired'] == true,
        janCode: _asText(json['jan_code']),
        sku: _asText(json['sku']),
        trackingMode: _asText(json['tracking_mode']),
        serialCount: _asInt(json['serial_count'] ?? 0),
      );

  @override
  List<Object?> get props =>
      [lotId, lotCode, productId, expiryDate, daysToExpiry, isExpired];
}
