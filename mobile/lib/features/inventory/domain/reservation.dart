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

/// One parcel promised to one reservation (`stock_allocations`, 0064).
///
/// The plan, not the movement: an allocation says which stock *will* be taken
/// and changes no quantity. §6 — Allocationしただけでは在庫を減らさない.
class StockAllocation extends Equatable {
  const StockAllocation({
    required this.id,
    required this.stockUnitId,
    required this.quantity,
    this.status,
    this.lotId,
    this.lotCode,
    this.expiryDate,
    this.binId,
  });

  final int id;
  final int stockUnitId;
  final int quantity;

  /// The condition the promised parcel is in — a picker needs to know before
  /// walking to it.
  final String? status;
  final int? lotId;
  final String? lotCode;
  final DateTime? expiryDate;
  final int? binId;

  factory StockAllocation.fromJson(Map<String, dynamic> json) => StockAllocation(
        id: _asInt(json['allocation_id'] ?? json['id']),
        stockUnitId: _asInt(json['stock_unit_id']),
        quantity: _asInt(json['quantity']),
        status: _asText(json['status']),
        lotId: _asIntOrNull(json['lot_id']),
        lotCode: _asText(json['lot_code']),
        expiryDate: DateTime.tryParse('${json['expiry_date']}'),
        binId: _asIntOrNull(json['bin_id']),
      );

  @override
  List<Object?> get props => [id, stockUnitId, quantity, status, lotId];
}

/// A promise made against stock (`stock_reservations`, 0064).
///
/// ACTIVE reservations are what `stock_available()` subtracts, which is why the
/// list defaults to them. A row past its `expires_at` still reads ACTIVE but
/// holds nothing — the clock decides, not a cleanup job — so [isExpired] is a
/// separate fact from [status] rather than a third state.
class Reservation extends Equatable {
  const Reservation({
    required this.id,
    required this.productId,
    required this.productName,
    required this.warehouseId,
    required this.quantity,
    required this.status,
    this.fulfilledQuantity = 0,
    this.allocatedQuantity = 0,
    this.janCode,
    this.sku,
    this.warehouseName,
    this.referenceType = 'manual',
    this.referenceId,
    this.expiresAt,
    this.isExpired = false,
    this.note,
    this.createdAt,
    this.allocations = const [],
  });

  final int id;
  final int productId;
  final String productName;
  final int warehouseId;
  final int quantity;

  /// ACTIVE / FULFILLED / RELEASED. Kept as the code so a status added later
  /// shows as itself instead of breaking the parse.
  final String status;
  final int fulfilledQuantity;
  final int allocatedQuantity;
  final String? janCode;
  final String? sku;
  final String? warehouseName;

  /// What the promise is for: sales_order / shipment / transfer / work_order /
  /// manual, with the document's own id beside it.
  final String referenceType;
  final String? referenceId;
  final DateTime? expiresAt;

  /// Past its expiry. Reads ACTIVE and holds nothing — see the class comment.
  final bool isExpired;
  final String? note;
  final DateTime? createdAt;
  final List<StockAllocation> allocations;

  bool get isActive => status == 'ACTIVE';

  /// Promised but not yet pinned to particular parcels. A picker cannot be sent
  /// anywhere for this part of it.
  int get unallocated => quantity - allocatedQuantity;

  /// Still owed on this promise after what has already shipped.
  int get outstanding => quantity - fulfilledQuantity;

  /// Holding stock right now: ACTIVE, not lapsed, and not fully shipped.
  bool get isHolding => isActive && !isExpired && outstanding > 0;

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final raw = json['allocations'];
    return Reservation(
      id: _asInt(json['id']),
      productId: _asInt(json['product_id']),
      productName: (json['product_name'] ?? '').toString(),
      warehouseId: _asInt(json['warehouse_id']),
      quantity: _asInt(json['quantity']),
      status: (json['status'] ?? '').toString(),
      fulfilledQuantity: _asInt(json['fulfilled_quantity'] ?? 0),
      allocatedQuantity: _asInt(json['allocated_quantity'] ?? 0),
      janCode: _asText(json['jan_code']),
      sku: _asText(json['sku']),
      warehouseName: _asText(json['warehouse_name']),
      referenceType: (json['reference_type'] ?? 'manual').toString(),
      referenceId: _asText(json['reference_id']),
      expiresAt: DateTime.tryParse('${json['expires_at']}')?.toLocal(),
      isExpired: json['is_expired'] == true,
      note: _asText(json['note']),
      createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
      allocations: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => StockAllocation.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        warehouseId,
        quantity,
        status,
        fulfilledQuantity,
        allocatedQuantity,
        referenceType,
        referenceId,
        isExpired,
        allocations,
      ];
}

/// A parcel promised to more than it now holds (`over_allocated_stock`, 0064).
///
/// This exists because an allocation never blocks a stock movement: if a
/// shipment takes stock someone else had allocated, the shipment wins — it is
/// what physically happened — and the over-commitment is reported instead of
/// being prevented. An empty list is the healthy state.
class OverAllocatedStock extends Equatable {
  const OverAllocatedStock({
    required this.stockUnitId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.allocated,
    required this.over,
    this.warehouseId,
    this.status,
  });

  final int stockUnitId;
  final int productId;
  final String productName;

  /// What the parcel actually holds now.
  final int quantity;

  /// What has been promised out of it.
  final int allocated;

  /// The gap someone has to resolve, by releasing an allocation or by finding
  /// more stock.
  final int over;
  final int? warehouseId;
  final String? status;

  factory OverAllocatedStock.fromJson(Map<String, dynamic> json) =>
      OverAllocatedStock(
        stockUnitId: _asInt(json['stock_unit_id']),
        productId: _asInt(json['product_id']),
        productName: (json['product_name'] ?? '').toString(),
        quantity: _asInt(json['quantity']),
        allocated: _asInt(json['allocated']),
        over: _asInt(json['over']),
        warehouseId: _asIntOrNull(json['warehouse_id']),
        status: _asText(json['status']),
      );

  @override
  List<Object?> get props =>
      [stockUnitId, productId, quantity, allocated, over, warehouseId];
}
