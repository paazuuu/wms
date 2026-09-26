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
    this.incomingUnlinked = 0,
    this.incomingOrders = const [],
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

  /// What open purchase orders still have to deliver, every supplier added up.
  final int incoming;

  /// The part of [incoming] no order is linked to — bought ahead (見込み).
  final int incomingUnlinked;

  /// [incoming] broken down per purchase order, so each supplier's share shows.
  final List<IncomingPurchase> incomingOrders;
  final int canFillNow;

  /// Backorder that neither free stock nor incoming purchases cover.
  final int toPurchase;
  final int? preferredSupplierId;
  final String? preferredSupplierName;
  final List<OpenDemandLine> lines;

  String get displayName => productName.isNotEmpty ? productName : janCode;

  /// Listed only because something is on its way, not because anyone waits.
  bool get isAheadOnly => backordered == 0;

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
        incomingUnlinked: _asInt(json['incoming_unlinked']),
        incomingOrders: (json['incoming_orders'] as List?)
                ?.whereType<Map>()
                .map((e) => IncomingPurchase.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
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
        incomingUnlinked,
        incomingOrders,
        preferredSupplierId,
        lines,
      ];
}

/// One open purchase order still bringing a product in.
class IncomingPurchase extends Equatable {
  const IncomingPurchase({
    required this.purchaseOrderId,
    required this.outstanding,
    this.poNumber,
    this.supplierName = '',
    this.status = '',
    this.expectedDate,
    this.unlinked = 0,
  });

  final int purchaseOrderId;
  final String? poNumber;
  final String supplierName;
  final String status;
  final DateTime? expectedDate;
  final int outstanding;

  /// Of [outstanding], what no order is linked to.
  final int unlinked;

  factory IncomingPurchase.fromJson(Map<String, dynamic> json) => IncomingPurchase(
        purchaseOrderId: _asInt(json['purchase_order_id']),
        poNumber: json['po_number'] as String?,
        supplierName: (json['supplier_name'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        expectedDate: json['expected_date'] == null
            ? null
            : DateTime.tryParse('${json['expected_date']}'),
        outstanding: _asInt(json['outstanding']),
        unlinked: _asInt(json['unlinked']),
      );

  @override
  List<Object?> get props =>
      [purchaseOrderId, poNumber, supplierName, status, outstanding, unlinked];
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

/// One line of a purchase order raised from demand. [demands] says which
/// waiting order lines it is for and how many of each; what they do not add
/// up to is bought ahead (見込み). Null [demands] lets the server link the
/// quantity oldest-first instead.
class DemandPurchaseLine {
  const DemandPurchaseLine({
    required this.janCode,
    required this.quantity,
    this.productName = '',
    this.unitPrice,
    this.demands,
  });

  final String janCode;
  final String productName;
  final int quantity;
  final double? unitPrice;
  final List<DemandLink>? demands;

  int get linkedQuantity => (demands ?? const []).fold(0, (s, d) => s + d.quantity);

  Map<String, dynamic> toJson() => {
        'jan_code': janCode,
        'product_name': productName,
        'quantity': quantity,
        if (unitPrice != null) 'unit_price': unitPrice,
        if (demands != null)
          'demands': [
            for (final d in demands!)
              if (d.quantity > 0) d.toJson(),
          ],
      };
}

/// "This many of the purchase are for that sales-order line."
class DemandLink extends Equatable {
  const DemandLink({required this.salesOrderLineId, required this.quantity});

  final int salesOrderLineId;
  final int quantity;

  Map<String, dynamic> toJson() =>
      {'sales_order_line_id': salesOrderLineId, 'quantity': quantity};

  @override
  List<Object?> get props => [salesOrderLineId, quantity];
}

/// The default split of [quantity] over the lines waiting for a product, the
/// same way the server would do it: oldest first, skipping what free stock
/// ([freeStock]) will reach first and what other purchases already cover.
/// [taken] is what earlier purchases in the same batch already claimed per
/// line, so two suppliers' rows do not both claim the same order.
List<DemandLink> defaultDemandLinks({
  required List<OpenDemandLine> lines,
  required int quantity,
  required int freeStock,
  Map<int, int> taken = const {},
}) {
  var left = quantity;
  var free = freeStock > 0 ? freeStock : 0;
  final out = <DemandLink>[];
  for (final l in lines) {
    if (left <= 0) break;
    var uncovered = l.backordered - l.onOrder - (taken[l.salesOrderLineId] ?? 0);
    if (uncovered <= 0) continue;
    final fromFree = free < uncovered ? free : uncovered;
    free -= fromFree;
    uncovered -= fromFree;
    if (uncovered <= 0) continue;
    final take = left < uncovered ? left : uncovered;
    out.add(DemandLink(salesOrderLineId: l.salesOrderLineId, quantity: take));
    left -= take;
  }
  return out;
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
