import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

int? _asIntOrNull(dynamic v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

String? _asText(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// One inspection line still to be settled, with what the bulk screen groups
/// by: when the goods arrived, which receipt and purchase order they came on,
/// and which product they are (`open_inspection_lines`, 0099).
class OpenInspectionLine extends Equatable {
  const OpenInspectionLine({
    required this.itemId,
    required this.inspectionId,
    required this.janCode,
    required this.quantity,
    this.reconciliationId,
    this.referenceNo,
    this.arrivedOn,
    this.deliveryNumber,
    this.supplierName,
    this.purchaseOrderId,
    this.poNumber,
    this.productId,
    this.productName,
    this.lot,
    this.checked = false,
  });

  final int itemId;
  final int inspectionId;
  final int? reconciliationId;
  final String? referenceNo;
  final DateTime? arrivedOn;
  final String? deliveryNumber;
  final String? supplierName;
  final int? purchaseOrderId;
  final String? poNumber;
  final String janCode;
  final int? productId;
  final String? productName;
  final int quantity;
  final String? lot;

  /// Someone has already recorded a finding on it (not yet settled).
  final bool checked;

  String get title => productName ?? janCode;

  factory OpenInspectionLine.fromJson(Map<String, dynamic> json) => OpenInspectionLine(
        itemId: _asInt(json['item_id']),
        inspectionId: _asInt(json['inspection_id']),
        reconciliationId: _asIntOrNull(json['reconciliation_id']),
        referenceNo: _asText(json['reference_no']),
        arrivedOn: DateTime.tryParse('${json['arrived_on']}'),
        deliveryNumber: _asText(json['delivery_number']),
        supplierName: _asText(json['supplier_name']),
        purchaseOrderId: _asIntOrNull(json['purchase_order_id']),
        poNumber: _asText(json['po_number']),
        janCode: (json['jan_code'] ?? '').toString(),
        productId: _asIntOrNull(json['product_id']),
        productName: _asText(json['product_name']),
        quantity: _asInt(json['quantity']),
        lot: _asText(json['lot']),
        checked: (json['result'] ?? 'PENDING') != 'PENDING',
      );

  @override
  List<Object?> get props => [itemId, inspectionId, quantity, checked];
}

/// What a bulk pass did (`pass_inspection_items`, 0099).
class BulkPassResult extends Equatable {
  const BulkPassResult({
    required this.items,
    this.releasedToOk = 0,
    this.notInQcPending = 0,
    this.inspections = 0,
    this.closedInspections = 0,
  });

  final int items;
  final int releasedToOk;
  final int notInQcPending;
  final int inspections;
  final int closedInspections;

  factory BulkPassResult.fromJson(Map<String, dynamic> json) => BulkPassResult(
        items: _asInt(json['items']),
        releasedToOk: _asInt(json['released_to_ok']),
        notInQcPending: _asInt(json['not_in_qc_pending']),
        inspections: _asInt(json['inspections']),
        closedInspections: _asInt(json['closed_inspections']),
      );

  @override
  List<Object?> get props => [items, releasedToOk, notInQcPending, inspections, closedInspections];
}
