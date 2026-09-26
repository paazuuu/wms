import 'package:equatable/equatable.dart';

/// What one supplier calls one of our products (0087): its own name, and its
/// own code when it has one. Used to find the product by the supplier's words
/// and to match the supplier's delivery notes; never printed downstream.
class SupplierProductName extends Equatable {
  const SupplierProductName({
    required this.supplierId,
    required this.supplierName,
    this.id,
    this.supplierDisplayName = '',
    this.productId,
    this.janCode,
    this.productName,
    this.supplierCode,
    this.note,
  });

  /// Null on the summary embedded in a product row.
  final int? id;
  final int supplierId;

  /// The supplier itself, as registered.
  final String supplierDisplayName;
  final int? productId;
  final String? janCode;
  final String? productName;

  /// The supplier's code and name for the product.
  final String? supplierCode;
  final String supplierName;
  final String? note;

  static int? _int(dynamic v) =>
      v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

  factory SupplierProductName.fromJson(Map<String, dynamic> json) => SupplierProductName(
        id: _int(json['id']),
        supplierId: _int(json['supplier_id']) ?? 0,
        supplierDisplayName: (json['supplier_display_name'] ?? '').toString(),
        productId: _int(json['product_id']),
        janCode: json['jan_code'] as String?,
        productName: json['product_name'] as String?,
        supplierCode: json['supplier_code'] as String?,
        supplierName: (json['supplier_name'] ?? '').toString(),
        note: json['note'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, supplierId, productId, supplierCode, supplierName, note];
}
