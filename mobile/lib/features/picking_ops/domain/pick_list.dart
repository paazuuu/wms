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

class PickTask extends Equatable {
  const PickTask({
    required this.id,
    required this.janCode,
    this.productName = '',
    required this.plannedQuantity,
    this.pickedQuantity,
    this.variance,
    this.status = PickTaskStatus.pending,
    this.binId,
    this.binCode,
    this.note,
    this.pickedAt,
  });

  final int id;
  final String janCode;
  final String productName;
  final int plannedQuantity;
  final int? pickedQuantity;
  final int? variance;
  final PickTaskStatus status;
  final int? binId;
  final String? binCode;
  final String? note;
  final DateTime? pickedAt;

  bool get isDone => pickedQuantity != null;

  factory PickTask.fromJson(Map<String, dynamic> json) => PickTask(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productName: json['product_name'] as String? ?? '',
        plannedQuantity: _asInt(json['planned_quantity']),
        pickedQuantity: _asIntOrNull(json['picked_quantity']),
        variance: _asIntOrNull(json['variance']),
        status: PickTaskStatus.parse(json['status'] as String?),
        binId: _asIntOrNull(json['bin_id']),
        binCode: json['bin_code'] as String?,
        note: json['note'] as String?,
        pickedAt: DateTime.tryParse('${json['picked_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props =>
      [id, janCode, plannedQuantity, pickedQuantity, variance, status];
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
