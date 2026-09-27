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
    this.finalizedAt,
    this.countedQuantity,
    this.noteQuantity,
    this.noteProductName,
  });

  /// What the supplier's delivery note says for this line (0101).
  final int? noteQuantity;
  final String? noteProductName;

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

  /// Settled on its own (0099): its goods have already moved out of
  /// inspection and the line can no longer change, even while other lines of
  /// the same inspection are still open.
  final DateTime? finalizedAt;
  bool get isFinal => finalizedAt != null;

  /// What the inspector counted (0100) — null until counted. Inspection's
  /// first job is whether this matches what arrived ([actualQuantity]).
  final int? countedQuantity;
  bool get isCounted => countedQuantity != null;

  /// counted − arrived: negative is short, positive is over, 0 matches.
  int? get countDifference =>
      countedQuantity == null ? null : countedQuantity! - actualQuantity;
  bool get countMatches => countDifference == 0;

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
        finalizedAt: DateTime.tryParse('${json['finalized_at']}')?.toLocal(),
        countedQuantity: json['counted_quantity'] == null
            ? null
            : _asInt(json['counted_quantity']),
        noteQuantity:
            json['note_quantity'] == null ? null : _asInt(json['note_quantity']),
        noteProductName: json['note_product_name'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, janCode, passedQuantity, failedQuantity, discrepancy, result, finalizedAt,
       countedQuantity, noteQuantity];
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
    this.stockEffect,
    this.arrivedOn,
  });

  /// When the goods arrived (the receipt's arrival date, 0099).
  final DateTime? arrivedOn;

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

  /// What closing this inspection did to the stock (0068). Only present on the
  /// response to completing it — a later read of the same inspection has the
  /// status but not the movement, because the movement is a past event and lives
  /// in the ledger, not on this document.
  final InspectionStockEffect? stockEffect;

  bool get isOpen => status == QcResult.pending;
  int get lineCount => items.isNotEmpty ? items.length : (itemCount ?? 0);
  int get uncheckedCount => items.where((i) => !i.isChecked).length;

  /// Lines whose count has been taken and matches what arrived (0100).
  int get matchedCount => items.where((i) => i.countMatches).length;
  int get countedCount => items.where((i) => i.isCounted).length;
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
        arrivedOn: DateTime.tryParse('${json['arrived_on']}'),
        stockEffect: json['stock_effect'] is Map
            ? InspectionStockEffect.fromJson(
                (json['stock_effect'] as Map).cast<String, dynamic>())
            : null,
      );

  @override
  List<Object?> get props => [id, status, items, itemCount, stockEffect];
}

/// What completing an inspection released and held (§13, 0068).
///
/// This is the answer to the question a status cannot answer: "PARTIAL" does not
/// tell an inspector whether the thirty they passed are sellable now. It says how
/// much moved to OK, how much was held and where, and how much the inspection
/// judged that was never in QC_PENDING to be moved.
class InspectionStockEffect extends Equatable {
  const InspectionStockEffect({
    this.releasedToOk = 0,
    this.failedQuantity = 0,
    this.failedTo,
    this.notInQcPending = 0,
    this.countShortHeld = 0,
  });

  /// Counted fewer than arrived: the uncounted remainder went to HOLD (0100).
  final int countShortHeld;

  final int releasedToOk;
  final int failedQuantity;

  /// Which status the failed goods went to — DAMAGED by default, HOLD for an
  /// item the inspector put on hold rather than failed.
  final String? failedTo;

  /// Quantity judged that was not sitting in QC_PENDING. Not an error: goods
  /// that never needed inspecting can still be inspected, and this says how much
  /// of what was judged was already available.
  final int notInQcPending;

  bool get movedNothing =>
      releasedToOk == 0 && failedQuantity == 0 && countShortHeld == 0;

  /// Worth telling the operator about: they judged more than was held, so part
  /// of what they checked was never gated.
  bool get hasUnheld => notInQcPending > 0;

  factory InspectionStockEffect.fromJson(Map<String, dynamic> json) =>
      InspectionStockEffect(
        releasedToOk: _asInt(json['released_to_ok']),
        failedQuantity: _asInt(json['failed_quantity']),
        failedTo: (json['failed_to'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['failed_to'] as String).trim(),
        notInQcPending: _asInt(json['not_in_qc_pending']),
        countShortHeld: _asInt(json['count_short_held']),
      );

  @override
  List<Object?> get props =>
      [releasedToOk, failedQuantity, failedTo, notInQcPending, countShortHeld];
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

/// A line's count after [InspectionRepository.recordCount] (0100).
class InspectionCount extends Equatable {
  const InspectionCount({required this.itemId, required this.counted, required this.received});

  final int itemId;
  final int counted;
  final int received;

  int get difference => counted - received;

  factory InspectionCount.fromJson(Map<String, dynamic> json) => InspectionCount(
        itemId: _asInt(json['item_id']),
        // Null after a 'clear'; reads as nothing counted.
        counted: json['counted'] == null ? 0 : _asInt(json['counted']),
        received: _asInt(json['received']),
      );

  @override
  List<Object?> get props => [itemId, counted, received];
}

/// How [InspectionRepository.recordCount] changes a line's count (0100/0101).
enum InspectionCountMode {
  /// The count is this.
  set('set'),

  /// Add this to the count so far — a scan, or a carton done today.
  add('add'),

  /// Ticked: the line is the right goods, about the right number — counted
  /// as the delivery note says, or as arrived when there is no note.
  check('check'),

  /// The tick or count taken back.
  clear('clear');

  const InspectionCountMode(this.wire);
  final String wire;
}
