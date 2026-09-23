import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
int? _asIntOrNull(dynamic v) => v == null
    ? null
    : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

/// Lifecycle of a pick wave (§15, 0077). OPEN before anyone is assigned,
/// PICKING once someone is, DONE when every list in it has been closed.
enum PickWaveStatus {
  open('OPEN'),
  picking('PICKING'),
  done('DONE'),
  cancelled('CANCELLED');

  const PickWaveStatus(this.wire);
  final String wire;

  static PickWaveStatus parse(String? v) => switch (v) {
        'PICKING' => PickWaveStatus.picking,
        'DONE' => PickWaveStatus.done,
        'CANCELLED' => PickWaveStatus.cancelled,
        _ => PickWaveStatus.open,
      };
}

/// One pick list a wave groups together, with its own progress — a list can
/// finish on its own whether or not its wave has (0077).
class PickWaveList extends Equatable {
  const PickWaveList({
    required this.pickListId,
    required this.shipmentPlanId,
    this.shipmentNumber,
    this.customerName,
    this.status = 'PICKING',
    this.taskCount = 0,
    this.pickedCount = 0,
  });

  final int pickListId;
  final int shipmentPlanId;
  final String? shipmentNumber;
  final String? customerName;
  final String status;
  final int taskCount;
  final int pickedCount;

  bool get isDone => pickedCount >= taskCount && taskCount > 0;

  factory PickWaveList.fromJson(Map<String, dynamic> json) => PickWaveList(
        pickListId: _asInt(json['pick_list_id']),
        shipmentPlanId: _asInt(json['shipment_plan_id']),
        shipmentNumber: json['shipment_number'] as String?,
        customerName: json['customer_name'] as String?,
        status: (json['status'] ?? 'PICKING').toString(),
        taskCount: _asInt(json['task_count']),
        pickedCount: _asInt(json['picked_count']),
      );

  @override
  List<Object?> get props => [pickListId, shipmentPlanId, status, taskCount, pickedCount];
}

/// One wave: several shipments' pick lists, walked as one sheet (§15, 0077).
/// A wave moves no stock and changes nothing about what a pick list means —
/// its lists are ordinary pick lists throughout.
class PickWave extends Equatable {
  const PickWave({
    required this.id,
    this.code,
    this.warehouseId,
    this.warehouseName,
    this.status = PickWaveStatus.open,
    this.assignedTo,
    this.assignedToName,
    this.priority = 100,
    this.note,
    this.createdAt,
    this.startedAt,
    this.completedAt,
    this.taskCount = 0,
    this.pickedCount = 0,
    this.listCount,
    this.lists = const [],
  });

  final int id;
  final String? code;
  final int? warehouseId;
  final String? warehouseName;
  final PickWaveStatus status;
  final String? assignedTo;
  final String? assignedToName;
  final int priority;
  final String? note;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int taskCount;
  final int pickedCount;

  /// Set on index rows, where [lists] itself is not loaded.
  final int? listCount;
  final List<PickWaveList> lists;

  int get totalLists => lists.isNotEmpty ? lists.length : (listCount ?? 0);
  bool get isAssigned => assignedTo != null;
  bool get isOpen => status == PickWaveStatus.open || status == PickWaveStatus.picking;

  factory PickWave.fromJson(Map<String, dynamic> json) => PickWave(
        id: _asInt(json['id']),
        code: json['code'] as String?,
        warehouseId: _asIntOrNull(json['warehouse_id']),
        warehouseName: json['warehouse_name'] as String?,
        status: PickWaveStatus.parse(json['status'] as String?),
        assignedTo: json['assigned_to'] as String?,
        assignedToName: json['assigned_to_name'] as String?,
        priority: _asInt(json['priority'] ?? 100),
        note: json['note'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        startedAt: DateTime.tryParse('${json['started_at']}')?.toLocal(),
        completedAt: DateTime.tryParse('${json['completed_at']}')?.toLocal(),
        taskCount: _asInt(json['task_count']),
        pickedCount: _asInt(json['picked_count']),
        listCount: _asIntOrNull(json['list_count']),
        lists: (json['lists'] as List?)
                ?.whereType<Map>()
                .map((e) => PickWaveList.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [id, code, status, assignedTo, taskCount, pickedCount, lists];
}

/// What `create_pick_wave` (0077) did: which shipments joined and which
/// could not, and why — reported rather than failing the whole batch.
class CreatePickWaveResult extends Equatable {
  const CreatePickWaveResult({
    required this.waveId,
    this.code,
    required this.pickListIds,
    required this.skipped,
  });

  final int waveId;
  final String? code;
  final List<int> pickListIds;
  final List<PickWaveSkip> skipped;

  factory CreatePickWaveResult.fromJson(Map<String, dynamic> json) =>
      CreatePickWaveResult(
        waveId: _asInt(json['wave_id']),
        code: json['code'] as String?,
        pickListIds: (json['pick_list_ids'] as List?)
                ?.map((e) => _asInt(e))
                .toList() ??
            const [],
        skipped: (json['skipped'] as List?)
                ?.whereType<Map>()
                .map((e) => PickWaveSkip.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [waveId, code, pickListIds, skipped];
}

class PickWaveSkip extends Equatable {
  const PickWaveSkip({required this.shipmentPlanId, required this.reason});

  final int shipmentPlanId;
  final String reason;

  factory PickWaveSkip.fromJson(Map<String, dynamic> json) => PickWaveSkip(
        shipmentPlanId: _asInt(json['shipment_plan_id']),
        reason: (json['reason'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [shipmentPlanId, reason];
}

/// One line of §15's sheet: a place and a parcel, with the total to take
/// there and which tasks those units are for. This is the whole economics of
/// wave picking — three orders wanting the same parcel become one stop.
class WaveStop extends Equatable {
  const WaveStop({
    this.binId,
    this.binCode,
    required this.productId,
    required this.janCode,
    this.productName = '',
    this.lotId,
    this.lotCode,
    this.expiryDate,
    this.stockUnitId,
    required this.quantity,
    this.lines = const [],
  });

  final int? binId;
  final String? binCode;
  final int productId;
  final String janCode;
  final String productName;
  final int? lotId;
  final String? lotCode;
  final String? expiryDate;
  final int? stockUnitId;
  final int quantity;
  final List<WaveStopLine> lines;

  factory WaveStop.fromJson(Map<String, dynamic> json) => WaveStop(
        binId: _asIntOrNull(json['bin_id']),
        binCode: json['bin_code'] as String?,
        productId: _asInt(json['product_id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productName: (json['product_name'] ?? '').toString(),
        lotId: _asIntOrNull(json['lot_id']),
        lotCode: json['lot_code'] as String?,
        expiryDate: json['expiry_date'] as String?,
        stockUnitId: _asIntOrNull(json['stock_unit_id']),
        quantity: _asInt(json['quantity']),
        lines: (json['lines'] as List?)
                ?.whereType<Map>()
                .map((e) => WaveStopLine.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props =>
      [binId, productId, janCode, lotId, stockUnitId, quantity, lines];
}

/// Which task, on which list, this stop's units are for.
class WaveStopLine extends Equatable {
  const WaveStopLine({
    required this.taskId,
    required this.pickListId,
    required this.shipmentPlanId,
    required this.quantity,
  });

  final int taskId;
  final int pickListId;
  final int shipmentPlanId;
  final int quantity;

  factory WaveStopLine.fromJson(Map<String, dynamic> json) => WaveStopLine(
        taskId: _asInt(json['task_id']),
        pickListId: _asInt(json['pick_list_id']),
        shipmentPlanId: _asInt(json['shipment_plan_id']),
        quantity: _asInt(json['quantity']),
      );

  @override
  List<Object?> get props => [taskId, pickListId, shipmentPlanId, quantity];
}

/// What the wave could not cover from shippable stock — reported rather than
/// silently rounded, so a picker's sheet and a supervisor's shortfall list
/// agree on the same numbers.
class WaveShort extends Equatable {
  const WaveShort({
    required this.taskId,
    required this.janCode,
    required this.short,
    required this.reason,
  });

  final int taskId;
  final String janCode;
  final int short;
  final String reason;

  factory WaveShort.fromJson(Map<String, dynamic> json) => WaveShort(
        taskId: _asInt(json['task_id']),
        janCode: (json['jan_code'] ?? '').toString(),
        short: _asInt(json['short'] ?? json['outstanding']),
        reason: (json['reason'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [taskId, janCode, short, reason];
}

/// The full sheet for one wave (`wave_pick_plan`, 0077).
class WavePickPlan extends Equatable {
  const WavePickPlan({
    required this.waveId,
    this.warehouseId,
    this.stops = const [],
    this.short = const [],
    this.totalUnits = 0,
  });

  final int waveId;
  final int? warehouseId;
  final List<WaveStop> stops;
  final List<WaveShort> short;
  final int totalUnits;

  bool get hasShortfall => short.isNotEmpty;

  factory WavePickPlan.fromJson(Map<String, dynamic> json) => WavePickPlan(
        waveId: _asInt(json['wave_id']),
        warehouseId: _asIntOrNull(json['warehouse_id']),
        stops: (json['stops'] as List?)
                ?.whereType<Map>()
                .map((e) => WaveStop.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        short: (json['short'] as List?)
                ?.whereType<Map>()
                .map((e) => WaveShort.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        totalUnits: _asInt(json['total_units']),
      );

  @override
  List<Object?> get props => [waveId, stops, short, totalUnits];
}
