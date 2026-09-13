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
      );

  @override
  List<Object?> get props => [id, status, soNumber, customerName, lines, lineCount];
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
