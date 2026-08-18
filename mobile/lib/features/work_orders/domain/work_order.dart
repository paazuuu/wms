import 'package:equatable/equatable.dart';

import 'work_order_item.dart';

/// Lifecycle of an assembly/kitting work order.
enum WorkOrderStatus { draft, pending, inProgress, completed, cancelled }

WorkOrderStatus parseWorkOrderStatus(String? value) => switch (value) {
      'pending' => WorkOrderStatus.pending,
      'in_progress' => WorkOrderStatus.inProgress,
      'completed' => WorkOrderStatus.completed,
      'cancelled' => WorkOrderStatus.cancelled,
      _ => WorkOrderStatus.draft,
    };

/// An assembly/kitting work order: build [quantity] units of [productName] by
/// consuming its bill-of-materials components.
class WorkOrder extends Equatable {
  const WorkOrder({
    required this.id,
    required this.workOrderNumber,
    required this.status,
    this.productId,
    this.productName = '',
    this.sku = '',
    this.quantity = 0,
    this.quantityProduced,
    this.startedAt,
    this.completedAt,
    this.notes,
    this.items = const [],
  });

  final int id;
  final String workOrderNumber;
  final WorkOrderStatus status;
  final int? productId;
  final String productName;
  final String sku;
  final int quantity;
  final int? quantityProduced;
  final String? startedAt;
  final String? completedAt;
  final String? notes;
  final List<WorkOrderItem> items;

  factory WorkOrder.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    final rawItems = json['items'];
    return WorkOrder(
      id: json['id'] as int,
      workOrderNumber: json['work_order_number'] as String? ?? '#${json['id']}',
      status: parseWorkOrderStatus(json['status'] as String?),
      productId: _asInt(json['product_id']),
      productName: product is Map<String, dynamic>
          ? (product['name'] as String? ?? '')
          : '',
      sku: product is Map<String, dynamic>
          ? (product['sku'] as String? ?? '')
          : '',
      quantity: _asInt(json['quantity']) ?? 0,
      quantityProduced: _asInt(json['quantity_produced']),
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
      notes: json['notes'] as String?,
      items: rawItems is List
          ? rawItems
              .map((e) => WorkOrderItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  @override
  List<Object?> get props => [id, workOrderNumber, status, quantity];
}
