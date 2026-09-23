import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
int? _asIntOrNull(dynamic v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

/// Lifecycle of one pick list (spec §14). Picking is a state of the order, not
/// a stock movement — nothing leaves the warehouse until shipping confirms it.
enum PickListStatus {
  picking('PICKING'),
  picked('PICKED'),
  cancelled('CANCELLED');

  const PickListStatus(this.wire);
  final String wire;

  static PickListStatus parse(String? v) => switch (v) {
        'PICKED' => PickListStatus.picked,
        'CANCELLED' => PickListStatus.cancelled,
        _ => PickListStatus.picking,
      };
}

/// A short/over pick is recorded, never silently rounded to plan (spec §10).
enum PickTaskStatus {
  pending,
  picked,
  short,
  over;

  static PickTaskStatus parse(String? v) => switch (v) {
        'PICKED' => PickTaskStatus.picked,
        'SHORT' => PickTaskStatus.short,
        'OVER' => PickTaskStatus.over,
        _ => PickTaskStatus.pending,
      };
}

/// One parcel a picker actually took for a task — §15's detail (0074),
/// mirroring `receipt_items` one door over: the task's planned/picked
/// quantities are the order, `items` is the fact of which parcels it was.
class PickTaskItem extends Equatable {
  const PickTaskItem({
    required this.id,
    required this.quantity,
    this.lotId,
    this.lotCode,
    this.expiryDate,
    this.serialId,
    this.serialNumber,
    this.binId,
    this.binCode,
    this.stockUnitId,
    this.note,
    this.createdAt,
  });

  final int id;
  final int quantity;
  final int? lotId;
  final String? lotCode;
  final String? expiryDate;
  final int? serialId;
  final String? serialNumber;
  final int? binId;
  final String? binCode;
  final int? stockUnitId;
  final String? note;
  final DateTime? createdAt;

  factory PickTaskItem.fromJson(Map<String, dynamic> json) => PickTaskItem(
        id: _asInt(json['id']),
        quantity: _asInt(json['quantity']),
        lotId: _asIntOrNull(json['lot_id']),
        lotCode: json['lot_code'] as String?,
        expiryDate: json['expiry_date'] as String?,
        serialId: _asIntOrNull(json['serial_id']),
        serialNumber: json['serial_number'] as String?,
        binId: _asIntOrNull(json['bin_id']),
        binCode: json['bin_code'] as String?,
        stockUnitId: _asIntOrNull(json['stock_unit_id']),
        note: json['note'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props => [id, quantity, lotId, serialId, binId, stockUnitId];
}

class PickTask extends Equatable {
  const PickTask({
    required this.id,
    required this.janCode,
    this.productId,
    this.productName = '',
    required this.plannedQuantity,
    this.pickedQuantity,
    this.variance,
    this.status = PickTaskStatus.pending,
    this.binId,
    this.binCode,
    this.note,
    this.pickedAt,
    this.pickingRule,
    this.items = const [],
  });

  final int id;
  final String janCode;
  final int? productId;
  final String productName;
  final int plannedQuantity;
  final int? pickedQuantity;
  final int? variance;
  final PickTaskStatus status;
  final int? binId;
  final String? binCode;
  final String? note;
  final DateTime? pickedAt;

  /// §16's rule for this product in this warehouse (0074) — FIFO/FEFO/LIFO/
  /// MANUAL. Null when the task has no linked product to look one up for.
  final String? pickingRule;

  /// §15's parcels actually taken (0074). Optional detail on top of
  /// [pickedQuantity]: a task can be fully picked with no items at all, when
  /// the picker just keyed a bare quantity.
  final List<PickTaskItem> items;

  bool get isDone => pickedQuantity != null;

  /// How much of the picked quantity has no parcel recorded for it — shown
  /// rather than hidden, the same reasoning `ReconLine.unattributedQuantity`
  /// uses on the way in.
  int get unattributedQuantity =>
      (pickedQuantity ?? 0) - items.fold(0, (s, i) => s + i.quantity);

  /// Still outstanding against the plan — what a picker has left to find,
  /// and what a new parcel's quantity field starts from.
  int get outstandingQuantity =>
      (plannedQuantity - (pickedQuantity ?? 0)).clamp(0, plannedQuantity);

  factory PickTask.fromJson(Map<String, dynamic> json) => PickTask(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productId: _asIntOrNull(json['product_id']),
        productName: json['product_name'] as String? ?? '',
        plannedQuantity: _asInt(json['planned_quantity']),
        pickedQuantity: _asIntOrNull(json['picked_quantity']),
        variance: _asIntOrNull(json['variance']),
        status: PickTaskStatus.parse(json['status'] as String?),
        binId: _asIntOrNull(json['bin_id']),
        binCode: json['bin_code'] as String?,
        note: json['note'] as String?,
        pickedAt: DateTime.tryParse('${json['picked_at']}')?.toLocal(),
        pickingRule: json['picking_rule'] as String?,
        items: (json['items'] as List?)
                ?.whereType<Map>()
                .map((e) => PickTaskItem.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props =>
      [id, janCode, plannedQuantity, pickedQuantity, variance, status, items];
}

/// One parcel `pick_candidates`/`pick_task_candidates` (0074) suggests taking,
/// in the product's picking-rule order. A read, not a plan: what the picker
/// actually takes is recorded separately as a [PickTaskItem].
class PickCandidate extends Equatable {
  const PickCandidate({
    required this.stockUnitId,
    required this.quantity,
    required this.free,
    required this.take,
    this.lotId,
    this.lotCode,
    this.expiryDate,
    this.serialId,
    this.serialNumber,
    this.binId,
    this.binCode,
    this.statusCode,
    this.reason,
  });

  final int stockUnitId;
  final int quantity;
  final int free;
  final int take;
  final int? lotId;
  final String? lotCode;
  final String? expiryDate;
  final int? serialId;
  final String? serialNumber;
  final int? binId;
  final String? binCode;
  final String? statusCode;
  final String? reason;

  factory PickCandidate.fromJson(Map<String, dynamic> json) => PickCandidate(
        stockUnitId: _asInt(json['stock_unit_id']),
        quantity: _asInt(json['quantity']),
        free: _asInt(json['free']),
        take: _asInt(json['take']),
        lotId: _asIntOrNull(json['lot_id']),
        lotCode: json['lot_code'] as String?,
        expiryDate: json['expiry_date'] as String?,
        serialId: _asIntOrNull(json['serial_id']),
        serialNumber: json['serial_number'] as String?,
        binId: _asIntOrNull(json['bin_id']),
        binCode: json['bin_code'] as String?,
        statusCode: json['status_code'] as String?,
        reason: json['reason'] as String?,
      );

  @override
  List<Object?> get props => [stockUnitId, quantity, free, take, lotId, serialId];
}

/// What `pick_task_candidates` returns for one task: the rule it used, what it
/// could cover, and what it could not (§16, 0074).
class PickCandidates extends Equatable {
  const PickCandidates({
    required this.rule,
    required this.requested,
    required this.short,
    this.candidates = const [],
  });

  final String rule;
  final int requested;
  final int short;
  final List<PickCandidate> candidates;

  factory PickCandidates.fromJson(Map<String, dynamic> json) => PickCandidates(
        rule: (json['rule'] ?? '').toString(),
        requested: _asInt(json['requested']),
        short: _asInt(json['short']),
        candidates: (json['candidates'] as List?)
                ?.whereType<Map>()
                .map((e) => PickCandidate.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [rule, requested, short, candidates];
}

class PickList extends Equatable {
  const PickList({
    required this.id,
    required this.shipmentPlanId,
    this.shipmentNumber,
    this.customerName,
    this.warehouseId,
    this.warehouseName,
    this.usesLocations = false,
    this.status = PickListStatus.picking,
    this.note,
    this.createdAt,
    this.completedAt,
    this.tasks = const [],
    this.taskCount,
    this.pickedCount,
    this.shortCount,
  });

  final int id;
  final int shipmentPlanId;
  final String? shipmentNumber;
  final String? customerName;
  final int? warehouseId;
  final String? warehouseName;
  final bool usesLocations;
  final PickListStatus status;
  final String? note;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final List<PickTask> tasks;
  final int? taskCount;
  final int? pickedCount;
  final int? shortCount;

  bool get isOpen => status == PickListStatus.picking;
  int get totalTasks => tasks.isNotEmpty ? tasks.length : (taskCount ?? 0);
  int get doneTasks =>
      tasks.isNotEmpty ? tasks.where((t) => t.isDone).length : (pickedCount ?? 0);
  int get pendingTasks => totalTasks - doneTasks;

  factory PickList.fromJson(Map<String, dynamic> json) => PickList(
        id: _asInt(json['id']),
        shipmentPlanId: _asInt(json['shipment_plan_id']),
        shipmentNumber: json['shipment_number'] as String?,
        customerName: json['customer_name'] as String?,
        warehouseId: _asIntOrNull(json['warehouse_id']),
        warehouseName: json['warehouse_name'] as String?,
        usesLocations: json['uses_locations'] == true,
        status: PickListStatus.parse(json['status'] as String?),
        note: json['note'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        completedAt: DateTime.tryParse('${json['completed_at']}')?.toLocal(),
        tasks: (json['tasks'] as List?)
                ?.whereType<Map>()
                .map((e) => PickTask.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        taskCount: _asIntOrNull(json['task_count']),
        pickedCount: _asIntOrNull(json['picked_count']),
        shortCount: _asIntOrNull(json['short_count']),
      );

  @override
  List<Object?> get props => [id, status, tasks, taskCount, pickedCount];
}

/// What completing a pick list changed.
class PickSummary extends Equatable {
  const PickSummary({
    required this.tasks,
    required this.pickedUnits,
    required this.plannedUnits,
    required this.shortLines,
    required this.overLines,
  });

  final int tasks;
  final int pickedUnits;
  final int plannedUnits;
  final int shortLines;
  final int overLines;

  factory PickSummary.fromJson(Map<String, dynamic> json) => PickSummary(
        tasks: _asInt(json['tasks']),
        pickedUnits: _asInt(json['picked_units']),
        plannedUnits: _asInt(json['planned_units']),
        shortLines: _asInt(json['short_lines']),
        overLines: _asInt(json['over_lines']),
      );

  @override
  List<Object?> get props => [tasks, pickedUnits, plannedUnits, shortLines, overLines];
}
