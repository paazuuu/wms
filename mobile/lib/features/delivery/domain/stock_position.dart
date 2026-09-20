import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

String? _asText(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// One parcel of stock as `stock_status_breakdown` returns it (0061): a
/// quantity in one condition, optionally from one lot.
class StockParcel extends Equatable {
  const StockParcel({
    required this.status,
    required this.statusName,
    required this.quantity,
    this.lotId,
    this.lotCode,
    this.expiryDate,
  });

  final String status;
  final String statusName;
  final int quantity;
  final int? lotId;
  final String? lotCode;
  final DateTime? expiryDate;

  factory StockParcel.fromJson(Map<String, dynamic> json) => StockParcel(
        status: (json['status'] ?? '').toString(),
        statusName: (json['name'] ?? json['status'] ?? '').toString(),
        quantity: _asInt(json['quantity']),
        lotId: json['lot_id'] == null ? null : _asInt(json['lot_id']),
        lotCode: _asText(json['lot_code']),
        expiryDate: DateTime.tryParse('${json['expiry_date']}'),
      );

  @override
  List<Object?> get props => [status, quantity, lotId, lotCode, expiryDate];
}

/// The four numbers §5 insists on keeping apart, for one product in one
/// warehouse (`stock_position`, 0064).
///
/// `on_hand = 100` was the old answer to every question. It cannot say that
/// twenty are quarantined or thirty promised to an order, and so it cannot
/// answer the only question an outbound flow asks: how many can ship today.
///
///   onHand     everything physically here, in every condition
///   available  usable, less what is promised — and NOT floored at zero, so a
///              negative genuinely means more is promised than can be shipped
///   reserved   promised to orders and not yet shipped
///   allocated  of that promise, how much has been pinned to specific parcels
class StockPosition extends Equatable {
  const StockPosition({
    required this.productId,
    this.warehouseId,
    this.onHand = 0,
    this.available = 0,
    this.reserved = 0,
    this.allocated = 0,
    this.parcels = const [],
  });

  final int productId;
  final int? warehouseId;
  final int onHand;
  final int available;
  final int reserved;
  final int allocated;
  final List<StockParcel> parcels;

  /// On hand but not usable: quarantined, damaged, held, awaiting QC. The
  /// difference the old single number hid.
  int get unavailable => onHand - reserved - available;

  /// More promised than can be shipped. Worth surfacing rather than clamping,
  /// because the fix is a purchase or a release, not a rounding.
  bool get isOverPromised => available < 0;

  factory StockPosition.fromJson(Map<String, dynamic> json) {
    // `by_status` is stock_status_breakdown's own shape: one row per
    // product × warehouse, each carrying its parcels. Asked for one product in
    // one warehouse there is at most one row, so its parcels are this
    // position's parcels.
    final byStatus = json['by_status'];
    final rows = byStatus is List ? byStatus.whereType<Map>().toList() : const [];
    final parcels = <StockParcel>[];
    for (final row in rows) {
      final raw = row['parcels'];
      if (raw is! List) continue;
      for (final p in raw.whereType<Map>()) {
        parcels.add(StockParcel.fromJson(p.cast<String, dynamic>()));
      }
    }
    return StockPosition(
      productId: _asInt(json['product_id']),
      warehouseId:
          json['warehouse_id'] == null ? null : _asInt(json['warehouse_id']),
      onHand: _asInt(json['on_hand']),
      available: _asInt(json['available']),
      reserved: _asInt(json['reserved']),
      allocated: _asInt(json['allocated']),
      parcels: parcels,
    );
  }

  @override
  List<Object?> get props =>
      [productId, warehouseId, onHand, available, reserved, allocated, parcels];
}
