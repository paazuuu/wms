import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// Outcome of an inspection or one of its lines (spec §10).
enum QcResult {
  pending('PENDING'),
  pass('PASS'),
  fail('FAIL'),
  partial('PARTIAL'),
  hold('HOLD');

  const QcResult(this.wire);
  final String wire;

  static QcResult parse(String? value) => switch (value) {
        'PASS' => QcResult.pass,
        'FAIL' => QcResult.fail,
        'PARTIAL' => QcResult.partial,
        'HOLD' => QcResult.hold,
        _ => QcResult.pending,
      };
}

/// One inspected line. `passed + failed` is what was physically checked, and
/// [discrepancy] (actual − expected) is recorded rather than corrected away.
class InspectionItem extends Equatable {
  const InspectionItem({
    required this.id,
    required this.janCode,
    required this.expectedQuantity,
    required this.actualQuantity,
    required this.passedQuantity,
    required this.failedQuantity,
    required this.discrepancy,
    required this.result,
    this.productName = '',
    this.lot,
    this.serial,
    this.expiry,
    this.packagingCondition,
    this.productCondition,
    this.labelOk,
    this.note,
  });

  final int id;
  final String janCode;
  final String productName;
  final int expectedQuantity;
  final int actualQuantity;
  final int passedQuantity;
  final int failedQuantity;

  /// actual − expected. Negative means short, positive means over.
  final int discrepancy;
  final QcResult result;
  final String? lot;
  final String? serial;
  final String? expiry;
  final String? packagingCondition;
  final String? productCondition;
  final bool? labelOk;
  final String? note;

  bool get isChecked => result != QcResult.pending;

  factory InspectionItem.fromJson(Map<String, dynamic> json) => InspectionItem(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productName: json['product_name'] as String? ?? '',
        expectedQuantity: _asInt(json['expected_quantity']),
        actualQuantity: _asInt(json['actual_quantity']),
        passedQuantity: _asInt(json['passed_quantity']),
        failedQuantity: _asInt(json['failed_quantity']),
        discrepancy: _asInt(json['discrepancy']),
        result: QcResult.parse(json['result'] as String?),
        lot: json['lot'] as String?,
        serial: json['serial'] as String?,
        expiry: json['expiry'] as String?,
        packagingCondition: json['packaging_condition'] as String?,
        productCondition: json['product_condition'] as String?,
        labelOk: json['label_ok'] as bool?,
        note: json['note'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, janCode, passedQuantity, failedQuantity, discrepancy, result];
}

/// A QC pass over one receipt.
class Inspection extends Equatable {
  const Inspection({
    required this.id,
    required this.status,
    this.warehouseId,
    this.reconciliationId,
    this.deliveryPlanId,
    this.deliveryNumber,
    this.supplierName,
    this.note,
    this.createdAt,
    this.completedAt,
    this.items = const [],
    this.itemCount,
  });

  final int id;
  final QcResult status;
  final int? warehouseId;
  final int? reconciliationId;
  final int? deliveryPlanId;
  final String? deliveryNumber;
  final String? supplierName;
  final String? note;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final List<InspectionItem> items;

  /// Set on list rows, where the items themselves are not loaded.
  final int? itemCount;

  bool get isOpen => status == QcResult.pending;
  int get lineCount => items.isNotEmpty ? items.length : (itemCount ?? 0);
  int get uncheckedCount => items.where((i) => !i.isChecked).length;
  int get failedUnits =>
      items.fold(0, (sum, i) => sum + i.failedQuantity);

  factory Inspection.fromJson(Map<String, dynamic> json) => Inspection(
        id: _asInt(json['id']),
        status: QcResult.parse(json['status'] as String?),
        warehouseId:
            json['warehouse_id'] == null ? null : _asInt(json['warehouse_id']),
        reconciliationId: json['reconciliation_id'] == null
            ? null
            : _asInt(json['reconciliation_id']),
        deliveryPlanId: json['delivery_plan_id'] == null
            ? null
            : _asInt(json['delivery_plan_id']),
        deliveryNumber: json['delivery_number'] as String?,
        supplierName: json['supplier_name'] as String?,
        note: json['note'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        completedAt: DateTime.tryParse('${json['completed_at']}')?.toLocal(),
        items: (json['items'] as List?)
                ?.whereType<Map>()
                .map((e) => InspectionItem.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        itemCount:
            json['item_count'] == null ? null : _asInt(json['item_count']),
      );

  @override
  List<Object?> get props => [id, status, items, itemCount];
}

/// What the operator recorded for one line.
class InspectionFinding {
  const InspectionFinding({
    required this.passedQuantity,
    required this.failedQuantity,
    this.lot,
    this.serial,
    this.expiry,
    this.packagingCondition,
    this.productCondition,
    this.labelOk,
    this.note,
    this.hold = false,
  });

  final int passedQuantity;
  final int failedQuantity;
  final String? lot;
  final String? serial;
  final String? expiry;
  final String? packagingCondition;
  final String? productCondition;
  final bool? labelOk;
  final String? note;

  /// Park the line for a decision instead of passing or failing it.
  final bool hold;

  Map<String, dynamic> toJson() => {
        'passed_quantity': passedQuantity,
        'failed_quantity': failedQuantity,
        if (lot != null && lot!.isNotEmpty) 'lot': lot,
        if (serial != null && serial!.isNotEmpty) 'serial': serial,
        if (expiry != null && expiry!.isNotEmpty) 'expiry': expiry,
        if (packagingCondition != null && packagingCondition!.isNotEmpty)
          'packaging_condition': packagingCondition,
        if (productCondition != null && productCondition!.isNotEmpty)
          'product_condition': productCondition,
        if (labelOk != null) 'label_ok': labelOk,
        if (note != null && note!.isNotEmpty) 'note': note,
        'hold': hold,
      };
}
