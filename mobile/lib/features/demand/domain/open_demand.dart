import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

int? _asIntOrNull(dynamic v) => v == null ? null : _asInt(v);

/// One product that approved sales orders are still waiting for (`open_demand`,
/// 0084): how much is ordered, how much is already promised from stock, and
/// how the rest is to be covered — from free stock now, from purchases already
/// on their way, or by buying more.
class OpenDemandItem extends Equatable {
  const OpenDemandItem({
    required this.warehouseId,
    required this.productId,
    required this.janCode,
    required this.productName,
    required this.ordered,
    required this.promised,
    required this.shipped,
    required this.backordered,
    required this.available,
    required this.incoming,
    required this.canFillNow,
    required this.toPurchase,
    this.warehouseName,
    this.preferredSupplierId,
    this.preferredSupplierName,
    this.lines = const [],
  });

  final int warehouseId;
  final String? warehouseName;
  final int productId;
  final String janCode;
  final String productName;
  final int ordered;
  final int promised;
  final int shipped;

  /// Ordered minus promised, over every waiting order line.
  final int backordered;

  /// Free to promise right now. May be negative when stock went missing.
  final int available;

  /// What open purchase orders still have to deliver.
  final int incoming;
  final int canFillNow;

  /// Backorder that neither free stock nor incoming purchases cover.
  final int toPurchase;
  final int? preferredSupplierId;
  final String? preferredSupplierName;
  final List<OpenDemandLine> lines;

  String get displayName => productName.isNotEmpty ? productName : janCode;

  factory OpenDemandItem.fromJson(Map<String, dynamic> json) => OpenDemandItem(
        warehouseId: _asInt(json['warehouse_id']),
        warehouseName: json['warehouse_name'] as String?,
        productId: _asInt(json['product_id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productName: (json['product_name'] ?? '').toString(),
        ordered: _asInt(json['ordered']),
        promised: _asInt(json['promised']),
        shipped: _asInt(json['shipped']),
        backordered: _asInt(json['backordered']),
        available: _asInt(json['available']),
        incoming: _asInt(json['incoming']),
        canFillNow: _asInt(json['can_fill_now']),
        toPurchase: _asInt(json['to_purchase']),
        preferredSupplierId: _asIntOrNull(json['preferred_supplier_id']),
        preferredSupplierName: json['preferred_supplier_name'] as String?,
        lines: (json['lines'] as List?)
                ?.whereType<Map>()
                .map((e) => OpenDemandLine.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [
        warehouseId,
        productId,
        janCode,
        ordered,
        promised,
        shipped,
        backordered,
        available,
        incoming,
        canFillNow,
        toPurchase,
        preferredSupplierId,
        lines,
      ];
}

/// One sales-order line waiting for a product, oldest approval first.
class OpenDemandLine extends Equatable {
  const OpenDemandLine({
    required this.salesOrderLineId,
    required this.salesOrderId,
    required this.ordered,
    required this.promised,
    required this.backordered,
    this.soNumber,
    this.customerName = '',
    this.requestedShipDate,
    this.shipped = 0,
    this.onOrder = 0,
  });

  final int salesOrderLineId;
  final int salesOrderId;
  final String? soNumber;
  final String customerName;
  final DateTime? requestedShipDate;
  final int ordered;
  final int promised;
  final int shipped;
  final int backordered;
  final int onOrder;

  factory OpenDemandLine.fromJson(Map<String, dynamic> json) => OpenDemandLine(
        salesOrderLineId: _asInt(json['sales_order_line_id']),
        salesOrderId: _asInt(json['sales_order_id']),
        soNumber: json['so_number'] as String?,
        customerName: (json['customer_name'] ?? '').toString(),
        requestedShipDate: json['requested_ship_date'] == null
            ? null
            : DateTime.tryParse('${json['requested_ship_date']}'),
        ordered: _asInt(json['ordered']),
        promised: _asInt(json['promised']),
        shipped: _asInt(json['shipped']),
        backordered: _asInt(json['backordered']),
        onOrder: _asInt(json['on_order']),
      );

  @override
  List<Object?> get props => [
        salesOrderLineId,
        salesOrderId,
        soNumber,
        ordered,
        promised,
        shipped,
        backordered,
        onOrder,
      ];
}

/// One line of a purchase order raised from demand. Without [demands] the
/// server links the quantity across the waiting orders oldest first.
class DemandPurchaseLine {
  const DemandPurchaseLine({
    required this.janCode,
    required this.quantity,
    this.productName = '',
    this.unitPrice,
  });

  final String janCode;
  final String productName;
  final int quantity;
  final double? unitPrice;

  Map<String, dynamic> toJson() => {
        'jan_code': janCode,
        'product_name': productName,
        'quantity': quantity,
        if (unitPrice != null) 'unit_price': unitPrice,
      };
}

/// What `create_purchase_order_from_demand` (0084) did.
class PurchaseFromDemandResult extends Equatable {
  const PurchaseFromDemandResult({
    required this.purchaseOrderId,
    required this.lines,
    required this.links,
  });

  final int purchaseOrderId;
  final int lines;

  /// How many sales-order lines the purchase was linked to.
  final int links;

  factory PurchaseFromDemandResult.fromJson(Map<String, dynamic> json) =>
      PurchaseFromDemandResult(
        purchaseOrderId: _asInt(json['purchase_order_id']),
        lines: _asInt(json['lines']),
        links: _asInt(json['links']),
      );

  @override
  List<Object?> get props => [purchaseOrderId, lines, links];
}

/// What `fill_backorders` (0084) promised from free stock.
class BackorderFillResult extends Equatable {
  const BackorderFillResult({required this.reservedUnits, this.filled = const []});

  final int reservedUnits;
  final List<BackorderFill> filled;

  factory BackorderFillResult.fromJson(Map<String, dynamic> json) =>
      BackorderFillResult(
        reservedUnits: _asInt(json['reserved_units']),
        filled: (json['filled'] as List?)
                ?.whereType<Map>()
                .map((e) => BackorderFill.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [reservedUnits, filled];
}

class BackorderFill extends Equatable {
  const BackorderFill({
    required this.salesOrderLineId,
    required this.salesOrderId,
    required this.reserved,
    this.soNumber,
    this.janCode = '',
    this.stillBackordered = 0,
  });

  final int salesOrderLineId;
  final int salesOrderId;
  final String? soNumber;
  final String janCode;
  final int reserved;
  final int stillBackordered;

  factory BackorderFill.fromJson(Map<String, dynamic> json) => BackorderFill(
        salesOrderLineId: _asInt(json['sales_order_line_id']),
        salesOrderId: _asInt(json['sales_order_id']),
        soNumber: json['so_number'] as String?,
        janCode: (json['jan_code'] ?? '').toString(),
        reserved: _asInt(json['reserved']),
        stillBackordered: _asInt(json['still_backordered']),
      );

  @override
  List<Object?> get props =>
      [salesOrderLineId, salesOrderId, soNumber, janCode, reserved, stillBackordered];
}
