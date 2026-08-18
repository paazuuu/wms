import 'package:equatable/equatable.dart';

/// A single counted line within a stock audit: the system's expected quantity
/// versus what was physically counted, and the resulting discrepancy.
class StockAuditItem extends Equatable {
  const StockAuditItem({
    required this.id,
    required this.productId,
    this.productName = '',
    this.sku = '',
    this.locationName,
    this.systemQuantity = 0,
    this.countedQuantity,
    this.discrepancy,
    this.status,
    this.notes,
  });

  final int id;
  final int productId;
  final String productName;
  final String sku;
  final String? locationName;
  final int systemQuantity;
  final int? countedQuantity;
  final int? discrepancy;
  final String? status;
  final String? notes;

  /// Whether this line has actually been counted yet.
  bool get isCounted => countedQuantity != null;

  /// Effective discrepancy: prefer the server value, else counted − system.
  int get effectiveDiscrepancy =>
      discrepancy ?? ((countedQuantity ?? systemQuantity) - systemQuantity);

  factory StockAuditItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    final location = json['location'];
    return StockAuditItem(
      id: json['id'] as int,
      productId: _asInt(json['product_id']) ?? 0,
      productName: product is Map<String, dynamic>
          ? (product['name'] as String? ?? '')
          : '',
      sku: product is Map<String, dynamic>
          ? (product['sku'] as String? ?? '')
          : '',
      locationName: location is Map<String, dynamic>
          ? location['name'] as String?
          : null,
      systemQuantity: _asInt(json['system_quantity']) ?? 0,
      countedQuantity: _asInt(json['counted_quantity']),
      discrepancy: _asInt(json['discrepancy']),
      status: json['status'] as String?,
      notes: json['notes'] as String?,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  @override
  List<Object?> get props =>
      [id, productId, systemQuantity, countedQuantity, discrepancy, status];
}
