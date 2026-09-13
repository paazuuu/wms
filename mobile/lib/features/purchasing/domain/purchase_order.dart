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
  });

  final int id;
  final String janCode;
  final String productName;
  final int quantity;
  final double? unitPrice;

  double get amount => (unitPrice ?? 0) * quantity;

  factory PurchaseOrderLine.fromJson(Map<String, dynamic> json) => PurchaseOrderLine(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productName: json['product_name'] as String? ?? '',
        quantity: _asInt(json['quantity']),
        unitPrice: _asDouble(json['unit_price']),
      );

  @override
  List<Object?> get props => [id, janCode, quantity, unitPrice];
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

  int get totalLineCount => lines.isNotEmpty ? lines.length : (lineCount ?? 0);
  double get computedTotal =>
      totalAmount ?? lines.fold(0.0, (sum, l) => sum + l.amount);

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
      );

  @override
  List<Object?> get props => [id, status, poNumber, supplierName, lines, lineCount];
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
