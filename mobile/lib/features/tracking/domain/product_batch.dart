import 'package:equatable/equatable.dart';

/// A tracked batch / lot of a product, with quantity and expiry window.
class ProductBatch extends Equatable {
  const ProductBatch({
    required this.id,
    required this.productId,
    this.batchNumber,
    this.quantity = 0,
    this.manufacturedDate,
    this.expiryDate,
    this.isExpired = false,
    this.notes,
  });

  final int id;
  final int productId;
  final String? batchNumber;
  final int quantity;
  final String? manufacturedDate;
  final String? expiryDate;
  final bool isExpired;
  final String? notes;

  /// Best available label for the batch, in mono type.
  String get displayNumber {
    final n = batchNumber?.trim();
    if (n != null && n.isNotEmpty) return n;
    return '#$id';
  }

  factory ProductBatch.fromJson(Map<String, dynamic> json) {
    return ProductBatch(
      id: json['id'] as int,
      productId: _asInt(json['product_id']) ?? 0,
      batchNumber: json['batch_number'] as String?,
      quantity: _asInt(json['quantity']) ?? 0,
      manufacturedDate: json['manufactured_date'] as String?,
      expiryDate: json['expiry_date'] as String?,
      isExpired: json['is_expired'] as bool? ?? false,
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
  List<Object?> get props => [id, productId, batchNumber, quantity, isExpired];
}
