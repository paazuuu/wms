import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

double? _asDouble(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

/// Lifecycle of a [SalesOrder] (0034). Deliberately does not move stock —
/// COMPLETED is a bookkeeping close, not a shipping event; actual
/// fulfillment still goes through the existing shipment-plan/picking/
/// packing flow.
enum SalesOrderStatus {
  draft('DRAFT'),
  submitted('SUBMITTED'),
  approved('APPROVED'),
  rejected('REJECTED'),
  cancelled('CANCELLED'),
  completed('COMPLETED');

  const SalesOrderStatus(this.wire);
  final String wire;

  static SalesOrderStatus parse(String? value) => switch (value) {
        'SUBMITTED' => SalesOrderStatus.submitted,
        'APPROVED' => SalesOrderStatus.approved,
        'REJECTED' => SalesOrderStatus.rejected,
        'CANCELLED' => SalesOrderStatus.cancelled,
        'COMPLETED' => SalesOrderStatus.completed,
        _ => SalesOrderStatus.draft,
      };
}

class SalesOrderLine extends Equatable {
  const SalesOrderLine({
    required this.id,
    required this.janCode,
    required this.quantity,
    this.productName = '',
    this.unitPrice,
    this.productId,
    this.promised = 0,
    this.shipped = 0,
    this.backordered = 0,
    this.onOrder = 0,
    this.purchaseOrders = const [],
  });

  final int id;
  final String janCode;
  final String productName;
  final int quantity;
  final double? unitPrice;

  /// Null while the JAN has no product record — nothing can be promised then.
  final int? productId;

  /// How much stock is set aside for this line, kept promises included (0084).
  final int promised;
  final int shipped;

  /// Ordered minus promised: what is still waiting for stock.
  final int backordered;

  /// What linked purchase orders are still to deliver for this line.
  final int onOrder;
  final List<SalesOrderLinePurchase> purchaseOrders;

  double get amount => (unitPrice ?? 0) * quantity;

  /// Promised and not yet shipped — what a new shipment would carry.
  int get readyToShip => (promised - shipped).clamp(0, quantity);

  factory SalesOrderLine.fromJson(Map<String, dynamic> json) => SalesOrderLine(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productName: json['product_name'] as String? ?? '',
        quantity: _asInt(json['quantity']),
        unitPrice: _asDouble(json['unit_price']),
        productId:
            json['product_id'] == null ? null : _asInt(json['product_id']),
        promised: _asInt(json['promised']),
        shipped: _asInt(json['shipped']),
        backordered: _asInt(json['backordered']),
        onOrder: _asInt(json['on_order']),
        purchaseOrders: (json['purchase_orders'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    SalesOrderLinePurchase.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [
        id,
        janCode,
        quantity,
        unitPrice,
        promised,
        shipped,
        backordered,
        onOrder,
        purchaseOrders,
      ];
}

/// A purchase order raised (partly) for one sales-order line (0084).
class SalesOrderLinePurchase extends Equatable {
  const SalesOrderLinePurchase({
    required this.purchaseOrderId,
    required this.quantity,
    this.poNumber,
    this.status = '',
    this.supplierName = '',
    this.filled = 0,
  });

  final int purchaseOrderId;
  final String? poNumber;
  final String status;
  final String supplierName;
  final int quantity;

  /// Promised to this line from what that purchase delivered (0086).
  final int filled;

  factory SalesOrderLinePurchase.fromJson(Map<String, dynamic> json) =>
      SalesOrderLinePurchase(
        purchaseOrderId: _asInt(json['purchase_order_id']),
        poNumber: json['po_number'] as String?,
        status: (json['status'] ?? '').toString(),
        supplierName: (json['supplier_name'] ?? '').toString(),
        quantity: _asInt(json['quantity']),
        filled: _asInt(json['filled']),
      );

  @override
  List<Object?> get props =>
      [purchaseOrderId, poNumber, status, supplierName, quantity, filled];
}

/// One shipment made from a sales order. An order may ship in several (0084).
class SalesOrderShipment extends Equatable {
  const SalesOrderShipment({
    required this.id,
    this.shipmentNumber,
    this.status = '',
  });

  final int id;
  final String? shipmentNumber;

  /// open / packing / shipped.
  final String status;

  bool get isShipped => status == 'shipped';

  factory SalesOrderShipment.fromJson(Map<String, dynamic> json) =>
      SalesOrderShipment(
        id: _asInt(json['id']),
        shipmentNumber: json['shipment_number'] as String?,
        status: (json['status'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [id, shipmentNumber, status];
}

/// One sales order (spec §46 checklist item 7, 0034) — what a customer
/// ordered, before fulfillment starts. Distinct from a shipment plan, which
/// represents an already-committed shipment feeding picking/packing/
/// shipping; this module is self-contained and does not move stock.
class SalesOrder extends Equatable {
  const SalesOrder({
    required this.id,
    required this.status,
    this.soNumber,
    this.customerId,
    this.customerName = '',
    this.warehouseId,
    this.warehouseName,
    this.orderDate,
    this.requestedShipDate,
    this.note,
    this.createdAt,
    this.lines = const [],
    this.lineCount,
    this.totalAmount,
    this.shipmentPlanId,
    this.openShipmentPlanId,
    this.shipments = const [],
    this.reservations = const [],
  });

  final int id;
  final SalesOrderStatus status;
  final String? soNumber;
  final int? customerId;
  final String customerName;
  final int? warehouseId;
  final String? warehouseName;
  final DateTime? orderDate;
  final DateTime? requestedShipDate;
  final String? note;
  final DateTime? createdAt;
  final List<SalesOrderLine> lines;

  /// Set on index rows, where lines themselves are not loaded.
  final int? lineCount;
  final double? totalAmount;

  /// The shipment still to go out if there is one, else the latest (0084).
  final int? shipmentPlanId;

  /// The one shipment that has not shipped yet, if any. At most one exists.
  final int? openShipmentPlanId;
  final List<SalesOrderShipment> shipments;

  /// §6's promise, wherever it is currently filed — against the order before a
  /// shipment exists, re-keyed to the shipment after (0073).
  final List<SalesOrderReservation> reservations;

  /// True once approval has turned this order into something the floor can
  /// pick. Distinct from [canComplete]: completing is the bookkeeping close,
  /// this is whether picking can start.
  bool get hasShipment => shipmentPlanId != null;

  bool get hasOpenShipment => openShipmentPlanId != null;

  int get backorderedUnits => lines.fold(0, (sum, l) => sum + l.backordered);
  int get readyToShipUnits => lines.fold(0, (sum, l) => sum + l.readyToShip);
  int get shippedUnits => lines.fold(0, (sum, l) => sum + l.shipped);
  int get orderedUnits => lines.fold(0, (sum, l) => sum + l.quantity);

  int get totalLineCount => lines.isNotEmpty ? lines.length : (lineCount ?? 0);
  double get computedTotal =>
      totalAmount ?? lines.fold(0.0, (sum, l) => sum + l.amount);

  bool get canSubmit => status == SalesOrderStatus.draft;
  bool get canApproveOrReject => status == SalesOrderStatus.submitted;
  bool get canCancel => [
        SalesOrderStatus.draft,
        SalesOrderStatus.submitted,
        SalesOrderStatus.approved,
      ].contains(status);
  bool get canComplete => status == SalesOrderStatus.approved;

  factory SalesOrder.fromJson(Map<String, dynamic> json) => SalesOrder(
        id: _asInt(json['id']),
        status: SalesOrderStatus.parse(json['status'] as String?),
        soNumber: json['so_number'] as String?,
        customerId:
            json['customer_id'] == null ? null : _asInt(json['customer_id']),
        customerName: (json['customer_name'] ?? '').toString(),
        warehouseId:
            json['warehouse_id'] == null ? null : _asInt(json['warehouse_id']),
        warehouseName: json['warehouse_name'] as String?,
        orderDate: DateTime.tryParse('${json['order_date']}'),
        requestedShipDate: DateTime.tryParse('${json['requested_ship_date']}'),
        note: json['note'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        lines: (json['lines'] as List?)
                ?.whereType<Map>()
                .map((e) => SalesOrderLine.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        lineCount:
            json['line_count'] == null ? null : _asInt(json['line_count']),
        totalAmount: _asDouble(json['total_amount']),
        shipmentPlanId: json['shipment_plan_id'] == null
            ? null
            : _asInt(json['shipment_plan_id']),
        openShipmentPlanId: json['open_shipment_plan_id'] == null
            ? null
            : _asInt(json['open_shipment_plan_id']),
        shipments: (json['shipments'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    SalesOrderShipment.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        reservations: (json['reservations'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    SalesOrderReservation.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [
        id,
        status,
        soNumber,
        customerName,
        lines,
        lineCount,
        shipmentPlanId,
        openShipmentPlanId,
        shipments,
      ];
}

/// One row of §6's promise (0064/0073) — how much of this order is backed by
/// stock already set aside, and whether it has been kept.
class SalesOrderReservation extends Equatable {
  const SalesOrderReservation({
    required this.id,
    required this.janCode,
    required this.quantity,
    required this.fulfilledQuantity,
    required this.status,
  });

  final int id;
  final String janCode;
  final int quantity;
  final int fulfilledQuantity;

  /// ACTIVE / FULFILLED / RELEASED (0064).
  final String status;

  bool get isFulfilled => status == 'FULFILLED';

  factory SalesOrderReservation.fromJson(Map<String, dynamic> json) =>
      SalesOrderReservation(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        quantity: _asInt(json['quantity']),
        fulfilledQuantity: _asInt(json['fulfilled_quantity']),
        status: (json['status'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [id, janCode, quantity, fulfilledQuantity, status];
}

/// What `approve_sales_order` (0073) actually did: best-effort, so this
/// reports which lines got a reservation and which did not, and why — a
/// shortfall is seen here rather than discovered at pick time.
class SalesOrderApprovalResult extends Equatable {
  const SalesOrderApprovalResult({
    required this.reservedLines,
    required this.skipped,
    this.backorderedUnits = 0,
  });

  final int reservedLines;
  final List<SalesOrderApprovalSkip> skipped;

  /// What approval could not promise and left waiting as backorder (0084).
  final int backorderedUnits;

  bool get hasSkipped => skipped.isNotEmpty;

  factory SalesOrderApprovalResult.fromJson(Map<String, dynamic> json) =>
      SalesOrderApprovalResult(
        reservedLines: _asInt(json['reserved_lines']),
        backorderedUnits: _asInt(json['backordered_units']),
        skipped: (json['skipped'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    SalesOrderApprovalSkip.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [reservedLines, skipped, backorderedUnits];
}

/// One line approval could not reserve stock for, and why. `unlinked_jan_code`
/// (no product registered yet) and `insufficient_available` (not enough on
/// hand right now) are the two reasons 0073 reports.
class SalesOrderApprovalSkip extends Equatable {
  const SalesOrderApprovalSkip({
    required this.lineId,
    required this.janCode,
    required this.reason,
    this.available,
    this.requested,
    this.reserved = 0,
    this.backordered = 0,
  });

  final int lineId;
  final String janCode;
  final String reason;
  final int? available;
  final int? requested;

  /// Since 0084 a short line is reserved as far as stock allows, not skipped.
  final int reserved;
  final int backordered;

  factory SalesOrderApprovalSkip.fromJson(Map<String, dynamic> json) =>
      SalesOrderApprovalSkip(
        lineId: _asInt(json['line_id']),
        janCode: (json['jan_code'] ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
        available: json['available'] == null ? null : _asInt(json['available']),
        requested: json['requested'] == null ? null : _asInt(json['requested']),
        reserved: _asInt(json['reserved']),
        backordered: _asInt(json['backordered']),
      );

  @override
  List<Object?> get props =>
      [lineId, janCode, reason, available, requested, reserved, backordered];
}

/// What `create_shipment_from_sales_order` (0073) did.
class ShipmentFromSalesOrderResult extends Equatable {
  const ShipmentFromSalesOrderResult({
    required this.shipmentPlanId,
    required this.lines,
    required this.reservationsRelinked,
  });

  final int shipmentPlanId;
  final int lines;
  final int reservationsRelinked;

  factory ShipmentFromSalesOrderResult.fromJson(Map<String, dynamic> json) =>
      ShipmentFromSalesOrderResult(
        shipmentPlanId: _asInt(json['shipment_plan_id']),
        lines: _asInt(json['lines']),
        reservationsRelinked: _asInt(json['reservations_relinked']),
      );

  @override
  List<Object?> get props => [shipmentPlanId, lines, reservationsRelinked];
}

/// One line the caller wants to order — the input shape for
/// `create_sales_order`'s `p_lines` jsonb array.
class SalesOrderLineDraft {
  const SalesOrderLineDraft({
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
