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
  });

  final int id;
  final String janCode;
  final String productName;
  final int quantity;
  final double? unitPrice;

  double get amount => (unitPrice ?? 0) * quantity;

  factory SalesOrderLine.fromJson(Map<String, dynamic> json) => SalesOrderLine(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productName: json['product_name'] as String? ?? '',
        quantity: _asInt(json['quantity']),
        unitPrice: _asDouble(json['unit_price']),
      );

  @override
  List<Object?> get props => [id, janCode, quantity, unitPrice];
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

  /// The live shipment this order became, once `create_shipment_from_sales_order`
  /// (0073) has been called. Null before that.
  final int? shipmentPlanId;

  /// §6's promise, wherever it is currently filed — against the order before a
  /// shipment exists, re-keyed to the shipment after (0073).
  final List<SalesOrderReservation> reservations;

  /// True once approval has turned this order into something the floor can
  /// pick. Distinct from [canComplete]: completing is the bookkeeping close,
  /// this is whether picking can start.
  bool get hasShipment => shipmentPlanId != null;

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
        reservations: (json['reservations'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    SalesOrderReservation.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props =>
      [id, status, soNumber, customerName, lines, lineCount, shipmentPlanId];
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
  });

  final int reservedLines;
  final List<SalesOrderApprovalSkip> skipped;

  bool get hasSkipped => skipped.isNotEmpty;

  factory SalesOrderApprovalResult.fromJson(Map<String, dynamic> json) =>
      SalesOrderApprovalResult(
        reservedLines: _asInt(json['reserved_lines']),
        skipped: (json['skipped'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    SalesOrderApprovalSkip.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [reservedLines, skipped];
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
  });

  final int lineId;
  final String janCode;
  final String reason;
  final int? available;
  final int? requested;

  factory SalesOrderApprovalSkip.fromJson(Map<String, dynamic> json) =>
      SalesOrderApprovalSkip(
        lineId: _asInt(json['line_id']),
        janCode: (json['jan_code'] ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
        available: json['available'] == null ? null : _asInt(json['available']),
        requested: json['requested'] == null ? null : _asInt(json['requested']),
      );

  @override
  List<Object?> get props => [lineId, janCode, reason, available, requested];
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
