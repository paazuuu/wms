import 'package:equatable/equatable.dart';

import 'purchase_order_item.dart';

/// Lifecycle of a purchase order. Only `sent` and `partial` can receive stock.
enum PurchaseOrderStatus { draft, sent, partial, received, cancelled }

PurchaseOrderStatus parsePurchaseOrderStatus(String? value) => switch (value) {
      'sent' => PurchaseOrderStatus.sent,
      'partial' => PurchaseOrderStatus.partial,
      'received' => PurchaseOrderStatus.received,
      'cancelled' => PurchaseOrderStatus.cancelled,
      _ => PurchaseOrderStatus.draft,
    };

class PurchaseOrder extends Equatable {
  const PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.status,
    this.statusLabel,
    this.supplierName,
    this.orderDate,
    this.expectedDate,
    this.receivedDate,
    this.currency,
    this.total,
    this.notes,
    this.itemsCount,
    this.canReceiveItems = false,
    this.items = const [],
  });

  final int id;
  final String poNumber;
  final PurchaseOrderStatus status;
  final String? statusLabel;
  final String? supplierName;
  final String? orderDate;
  final String? expectedDate;
  final String? receivedDate;
  final String? currency;
  final String? total;
  final String? notes;
  final int? itemsCount;
  final bool canReceiveItems;
  final List<PurchaseOrderItem> items;

  /// Only lines with stock still outstanding are receivable.
  List<PurchaseOrderItem> get receivableItems =>
      items.where((i) => i.remainingQuantity > 0).toList();

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      id: json['id'] as int,
      poNumber: json['po_number'] as String? ?? '',
      status: parsePurchaseOrderStatus(json['status'] as String?),
      statusLabel: json['status_label'] as String?,
      supplierName: _nestedName(json['supplier']),
      orderDate: json['order_date'] as String?,
      expectedDate: json['expected_date'] as String?,
      receivedDate: json['received_date'] as String?,
      currency: json['currency'] as String?,
      total: json['total'] == null ? null : '${json['total']}',
      notes: json['notes'] as String?,
      itemsCount: _asInt(json['items_count']),
      canReceiveItems: json['can_receive_items'] as bool? ?? false,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => PurchaseOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static String? _nestedName(dynamic value) {
    if (value is Map<String, dynamic>) return value['name'] as String?;
    return null;
  }

  @override
  List<Object?> get props => [id, poNumber, status, items];
}
