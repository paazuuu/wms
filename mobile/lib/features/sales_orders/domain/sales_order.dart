import 'package:equatable/equatable.dart';

import 'sales_order_item.dart';

/// Lifecycle of a sales order, matching the backend `OrderStatus` enum.
enum SalesOrderStatus { pending, processing, shipped, delivered, cancelled }

SalesOrderStatus parseSalesOrderStatus(String? value) => switch (value) {
      'processing' => SalesOrderStatus.processing,
      'shipped' => SalesOrderStatus.shipped,
      'delivered' => SalesOrderStatus.delivered,
      'cancelled' => SalesOrderStatus.cancelled,
      _ => SalesOrderStatus.pending,
    };

/// A customer (sales) order. `total` is a backend-formatted amount string.
class SalesOrder extends Equatable {
  const SalesOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.source,
    this.customerName,
    this.customerEmail,
    this.customerAddress,
    this.subtotal,
    this.tax,
    this.shipping,
    this.total,
    this.currency,
    this.orderDate,
    this.notes,
    this.itemsCount,
    this.items = const [],
  });

  final int id;
  final String orderNumber;
  final SalesOrderStatus status;
  final String? source;
  final String? customerName;
  final String? customerEmail;
  final String? customerAddress;
  final String? subtotal;
  final String? tax;
  final String? shipping;
  final String? total;
  final String? currency;
  final String? orderDate;
  final String? notes;
  final int? itemsCount;
  final List<SalesOrderItem> items;

  /// Amount with its currency prefix, e.g. "USD 42.00". Falls back to "—".
  String get displayTotal {
    final amount = total?.trim();
    if (amount == null || amount.isEmpty) return '—';
    final code = currency?.trim();
    return (code != null && code.isNotEmpty) ? '$code $amount' : amount;
  }

  factory SalesOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return SalesOrder(
      id: json['id'] as int,
      orderNumber: json['order_number'] as String? ?? '',
      status: parseSalesOrderStatus(json['status'] as String?),
      source: json['source'] as String?,
      customerName: json['customer_name'] as String?,
      customerEmail: json['customer_email'] as String?,
      customerAddress: json['customer_address'] as String?,
      subtotal: _asString(json['subtotal']),
      tax: _asString(json['tax']),
      shipping: _asString(json['shipping']),
      total: _asString(json['total']),
      currency: json['currency'] as String?,
      orderDate: json['order_date'] as String?,
      notes: json['notes'] as String?,
      itemsCount: _asInt(json['items_count']),
      items: rawItems is List
          ? rawItems
              .map((e) => SalesOrderItem.fromJson(e as Map<String, dynamic>))
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

  static String? _asString(dynamic value) => value?.toString();

  @override
  List<Object?> get props => [id, orderNumber, status, total];
}
