import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

double? _asDouble(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

/// Lifecycle of a [PurchaseOrder] (0033). Deliberately does not move stock —
/// COMPLETED is a bookkeeping close, not a receiving event; the actual
/// receipt still goes through the existing delivery-plan/reconciliation flow.
enum PurchaseOrderStatus {
  draft('DRAFT'),
  submitted('SUBMITTED'),
  approved('APPROVED'),
  rejected('REJECTED'),
  cancelled('CANCELLED'),
  completed('COMPLETED');

  const PurchaseOrderStatus(this.wire);
  final String wire;

  static PurchaseOrderStatus parse(String? value) => switch (value) {
        'SUBMITTED' => PurchaseOrderStatus.submitted,
        'APPROVED' => PurchaseOrderStatus.approved,
        'REJECTED' => PurchaseOrderStatus.rejected,
        'CANCELLED' => PurchaseOrderStatus.cancelled,
        'COMPLETED' => PurchaseOrderStatus.completed,
        _ => PurchaseOrderStatus.draft,
      };
}

class PurchaseOrderLine extends Equatable {
  const PurchaseOrderLine({
    required this.id,
    required this.janCode,
    required this.quantity,
    this.productName = '',
    this.unitPrice,
    this.planned = 0,
    this.received = 0,
    this.linked = 0,
    this.demands = const [],
  });

  final int id;
  final String janCode;
  final String productName;
  final int quantity;
  final double? unitPrice;

  /// Already expected on this order's delivery plans (0084: may be several).
  final int planned;
  final int received;

  /// How much of [quantity] is linked to sales orders; the rest is 見込み.
  final int linked;

  /// The sales-order lines this was bought for. One purchase line may cover
  /// many orders, and need not cover any of them in full.
  final List<PurchaseOrderLineDemand> demands;

  double get amount => (unitPrice ?? 0) * quantity;

  int get unplanned => quantity > planned ? quantity - planned : 0;

  /// Bought ahead of any order.
  int get unlinked => quantity > linked ? quantity - linked : 0;

  factory PurchaseOrderLine.fromJson(Map<String, dynamic> json) => PurchaseOrderLine(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productName: json['product_name'] as String? ?? '',
        quantity: _asInt(json['quantity']),
        unitPrice: _asDouble(json['unit_price']),
        planned: _asInt(json['planned']),
        received: _asInt(json['received']),
        linked: _asInt(json['linked']),
        demands: (json['demands'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    PurchaseOrderLineDemand.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props =>
      [id, janCode, quantity, unitPrice, planned, received, linked, demands];
}

/// A sales-order line a purchase-order line was raised for (0084).
class PurchaseOrderLineDemand extends Equatable {
  const PurchaseOrderLineDemand({
    required this.salesOrderLineId,
    required this.salesOrderId,
    required this.quantity,
    this.soNumber,
    this.customerName = '',
    this.filled = 0,
  });

  final int salesOrderLineId;
  final int salesOrderId;
  final String? soNumber;
  final String customerName;
  final int quantity;

  /// Promised to that order from what this purchase delivered.
  final int filled;

  factory PurchaseOrderLineDemand.fromJson(Map<String, dynamic> json) =>
      PurchaseOrderLineDemand(
        salesOrderLineId: _asInt(json['sales_order_line_id']),
        salesOrderId: _asInt(json['sales_order_id']),
        soNumber: json['so_number'] as String?,
        customerName: (json['customer_name'] ?? '').toString(),
        quantity: _asInt(json['quantity']),
        filled: _asInt(json['filled']),
      );

  @override
  List<Object?> get props =>
      [salesOrderLineId, salesOrderId, soNumber, customerName, quantity, filled];
}

/// One delivery plan receiving (part of) a purchase order.
class PurchaseOrderDeliveryPlan extends Equatable {
  const PurchaseOrderDeliveryPlan({
    required this.id,
    this.deliveryNumber,
    this.status = '',
  });

  final int id;
  final String? deliveryNumber;

  /// open / reconciling / partial / completed.
  final String status;

  bool get isCompleted => status == 'completed';

  factory PurchaseOrderDeliveryPlan.fromJson(Map<String, dynamic> json) =>
      PurchaseOrderDeliveryPlan(
        id: _asInt(json['id']),
        deliveryNumber: json['delivery_number'] as String?,
        status: (json['status'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [id, deliveryNumber, status];
}

/// One purchase order (spec §46 checklist item 6, 0033) — what was ordered
/// from a supplier, before it ships. Distinct from a delivery plan, which
/// represents an already-shipped delivery used for QC reconciliation; this
/// module is self-contained and does not move stock.
class PurchaseOrder extends Equatable {
  const PurchaseOrder({
    required this.id,
    required this.status,
    this.poNumber,
    this.supplierId,
    this.supplierName = '',
    this.warehouseId,
    this.warehouseName,
    this.orderDate,
    this.expectedDate,
    this.note,
    this.createdAt,
    this.lines = const [],
    this.lineCount,
    this.totalAmount,
    this.deliveryPlanId,
    this.deliveryPlans = const [],
  });

  final int id;
  final PurchaseOrderStatus status;
  final String? poNumber;
  final int? supplierId;
  final String supplierName;
  final int? warehouseId;
  final String? warehouseName;
  final DateTime? orderDate;
  final DateTime? expectedDate;
  final String? note;
  final DateTime? createdAt;
  final List<PurchaseOrderLine> lines;

  /// Set on index rows, where lines themselves are not loaded.
  final int? lineCount;
  final double? totalAmount;

  /// The delivery plan this order became, once
  /// `create_delivery_plan_from_purchase_order` (0083) has run. Only
  /// `purchase_order_detail` reads this — same asymmetry `SalesOrder.
  /// shipmentPlanId` has, since an index row never loads it either.
  final int? deliveryPlanId;

  /// Every delivery plan receiving this order — a supplier may split one order
  /// over several deliveries, or send its own delivery note to link (0084).
  final List<PurchaseOrderDeliveryPlan> deliveryPlans;

  int get totalLineCount => lines.isNotEmpty ? lines.length : (lineCount ?? 0);
  double get computedTotal =>
      totalAmount ?? lines.fold(0.0, (sum, l) => sum + l.amount);

  bool get hasDeliveryPlan => deliveryPlanId != null;

  /// Something ordered that no delivery plan expects yet.
  bool get hasUnplannedQuantity => lines.any((l) => l.unplanned > 0);

  bool get canSubmit => status == PurchaseOrderStatus.draft;
  bool get canApproveOrReject => status == PurchaseOrderStatus.submitted;
  bool get canCancel => [
        PurchaseOrderStatus.draft,
        PurchaseOrderStatus.submitted,
        PurchaseOrderStatus.approved,
      ].contains(status);
  bool get canComplete => status == PurchaseOrderStatus.approved;

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) => PurchaseOrder(
        id: _asInt(json['id']),
        status: PurchaseOrderStatus.parse(json['status'] as String?),
        poNumber: json['po_number'] as String?,
        supplierId:
            json['supplier_id'] == null ? null : _asInt(json['supplier_id']),
        supplierName: (json['supplier_name'] ?? '').toString(),
        warehouseId:
            json['warehouse_id'] == null ? null : _asInt(json['warehouse_id']),
        warehouseName: json['warehouse_name'] as String?,
        orderDate: DateTime.tryParse('${json['order_date']}'),
        expectedDate: DateTime.tryParse('${json['expected_date']}'),
        note: json['note'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        lines: (json['lines'] as List?)
                ?.whereType<Map>()
                .map((e) => PurchaseOrderLine.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        lineCount:
            json['line_count'] == null ? null : _asInt(json['line_count']),
        totalAmount: _asDouble(json['total_amount']),
        deliveryPlanId: json['delivery_plan_id'] == null
            ? null
            : _asInt(json['delivery_plan_id']),
        deliveryPlans: (json['delivery_plans'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    PurchaseOrderDeliveryPlan.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [
        id,
        status,
        poNumber,
        supplierName,
        lines,
        lineCount,
        deliveryPlanId,
        deliveryPlans,
      ];
}

/// One line the caller wants to order — the input shape for
/// `create_purchase_order`'s `p_lines` jsonb array.
class PurchaseOrderLineDraft {
  const PurchaseOrderLineDraft({
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

/// What `create_delivery_plan_from_purchase_order` (0083) did.
class DeliveryPlanFromPurchaseOrderResult extends Equatable {
  const DeliveryPlanFromPurchaseOrderResult({
    required this.deliveryPlanId,
    required this.lines,
  });

  final int deliveryPlanId;
  final int lines;

  factory DeliveryPlanFromPurchaseOrderResult.fromJson(
          Map<String, dynamic> json) =>
      DeliveryPlanFromPurchaseOrderResult(
        deliveryPlanId: _asInt(json['delivery_plan_id']),
        lines: _asInt(json['lines']),
      );

  @override
  List<Object?> get props => [deliveryPlanId, lines];
}

/// A sales-order line one purchase-order line could be linked to
/// (`purchase_line_demand_candidates`, 0086).
class PurchaseLinkCandidate extends Equatable {
  const PurchaseLinkCandidate({
    required this.salesOrderLineId,
    required this.salesOrderId,
    required this.ordered,
    this.soNumber,
    this.customerName = '',
    this.status = '',
    this.promised = 0,
    this.backordered = 0,
    this.onOrder = 0,
    this.linked = 0,
    this.filled = 0,
  });

  final int salesOrderLineId;
  final int salesOrderId;
  final String? soNumber;
  final String customerName;
  final String status;
  final int ordered;
  final int promised;
  final int backordered;

  /// On order across every purchase, this one included.
  final int onOrder;

  /// Linked to this purchase-order line now.
  final int linked;

  /// Already promised to it from what this purchase delivered.
  final int filled;

  factory PurchaseLinkCandidate.fromJson(Map<String, dynamic> json) =>
      PurchaseLinkCandidate(
        salesOrderLineId: _asInt(json['sales_order_line_id']),
        salesOrderId: _asInt(json['sales_order_id']),
        soNumber: json['so_number'] as String?,
        customerName: (json['customer_name'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        ordered: _asInt(json['ordered']),
        promised: _asInt(json['promised']),
        backordered: _asInt(json['backordered']),
        onOrder: _asInt(json['on_order']),
        linked: _asInt(json['linked']),
        filled: _asInt(json['filled']),
      );

  @override
  List<Object?> get props =>
      [salesOrderLineId, salesOrderId, ordered, promised, backordered, onOrder, linked, filled];
}

/// What `set_purchase_order_line_demands` (0086) changed.
class PurchaseLinkResult extends Equatable {
  const PurchaseLinkResult({
    required this.linkedUnits,
    this.releasedUnits = 0,
    this.reservedUnits = 0,
  });

  final int linkedUnits;

  /// Promised from this purchase to orders that lost their link, given back.
  final int releasedUnits;

  /// Promised to the new links from what already arrived.
  final int reservedUnits;

  factory PurchaseLinkResult.fromJson(Map<String, dynamic> json) => PurchaseLinkResult(
        linkedUnits: _asInt(json['linked_units']),
        releasedUnits: _asInt(json['released_units']),
        reservedUnits: _asInt(json['reserved_units']),
      );

  @override
  List<Object?> get props => [linkedUnits, releasedUnits, reservedUnits];
}
