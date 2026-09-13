import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// Lifecycle of a [WorkOrder] (0036). Unlike purchase/sales orders, which
/// deliberately never move stock, completing a work order does: every
/// component's required quantity leaves, the output quantity arrives, both
/// on the existing per-JAN stock ledger.
enum WorkOrderStatus {
  draft('DRAFT'),
  inProgress('IN_PROGRESS'),
  completed('COMPLETED'),
  cancelled('CANCELLED');

  const WorkOrderStatus(this.wire);
  final String wire;

  static WorkOrderStatus parse(String? value) => switch (value) {
        'IN_PROGRESS' => WorkOrderStatus.inProgress,
        'COMPLETED' => WorkOrderStatus.completed,
        'CANCELLED' => WorkOrderStatus.cancelled,
        _ => WorkOrderStatus.draft,
      };
}

class WorkOrderComponent extends Equatable {
  const WorkOrderComponent({
    required this.id,
    required this.janCode,
    required this.quantityRequired,
    this.productName = '',
  });

  final int id;
  final String janCode;
  final String productName;
  final int quantityRequired;

  factory WorkOrderComponent.fromJson(Map<String, dynamic> json) => WorkOrderComponent(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productName: json['product_name'] as String? ?? '',
        quantityRequired: _asInt(json['quantity_required']),
      );

  @override
  List<Object?> get props => [id, janCode, quantityRequired];
}

/// One work order (spec §46 checklist item 9, 0036) — a kitting/assembly
/// operation: consume a set of component JANs, produce one output JAN,
/// entirely inside one warehouse. Scoped to assembly only (many components
/// → one output); disassembly is a natural follow-up, not built here.
class WorkOrder extends Equatable {
  const WorkOrder({
    required this.id,
    required this.status,
    this.woNumber,
    this.warehouseId,
    this.warehouseName,
    this.outputJanCode = '',
    this.outputProductName = '',
    this.outputQuantity = 0,
    this.note,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.components = const [],
    this.componentCount,
  });

  final int id;
  final WorkOrderStatus status;
  final String? woNumber;
  final int? warehouseId;
  final String? warehouseName;
  final String outputJanCode;
  final String outputProductName;
  final int outputQuantity;
  final String? note;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final List<WorkOrderComponent> components;

  /// Set on index rows, where components themselves are not loaded.
  final int? componentCount;

  int get totalComponentCount =>
      components.isNotEmpty ? components.length : (componentCount ?? 0);

  bool get canStart => status == WorkOrderStatus.draft;
  bool get canCancel =>
      status == WorkOrderStatus.draft || status == WorkOrderStatus.inProgress;
  bool get canComplete => status == WorkOrderStatus.inProgress;

  factory WorkOrder.fromJson(Map<String, dynamic> json) => WorkOrder(
        id: _asInt(json['id']),
        status: WorkOrderStatus.parse(json['status'] as String?),
        woNumber: json['wo_number'] as String?,
        warehouseId:
            json['warehouse_id'] == null ? null : _asInt(json['warehouse_id']),
        warehouseName: json['warehouse_name'] as String?,
        outputJanCode: (json['output_jan_code'] ?? '').toString(),
        outputProductName: (json['output_product_name'] ?? '').toString(),
        outputQuantity: _asInt(json['output_quantity']),
        note: json['note'] as String?,
        startedAt: DateTime.tryParse('${json['started_at']}')?.toLocal(),
        completedAt: DateTime.tryParse('${json['completed_at']}')?.toLocal(),
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        components: (json['components'] as List?)
                ?.whereType<Map>()
                .map((e) => WorkOrderComponent.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        componentCount: json['component_count'] == null
            ? null
            : _asInt(json['component_count']),
      );

  @override
  List<Object?> get props =>
      [id, status, woNumber, outputJanCode, outputQuantity, components, componentCount];
}

/// One component the caller wants to consume — the input shape for
/// `create_work_order`'s `p_components` jsonb array.
class WorkOrderComponentDraft {
  const WorkOrderComponentDraft({
    required this.janCode,
    required this.quantityRequired,
    this.productName = '',
  });

  final String janCode;
  final String productName;
  final int quantityRequired;

  Map<String, dynamic> toJson() => {
        'jan_code': janCode,
        'product_name': productName,
        'quantity_required': quantityRequired,
      };
}
