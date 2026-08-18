import 'package:equatable/equatable.dart';

/// A serialized (unique) unit of a product, with a lifecycle status.
class ProductSerial extends Equatable {
  const ProductSerial({
    required this.id,
    required this.productId,
    this.serialNumber,
    this.status,
    this.notes,
  });

  final int id;
  final int productId;
  final String? serialNumber;
  final String? status;
  final String? notes;

  /// Best available label for the serial, in mono type.
  String get displayNumber {
    final n = serialNumber?.trim();
    if (n != null && n.isNotEmpty) return n;
    return '#$id';
  }

  factory ProductSerial.fromJson(Map<String, dynamic> json) {
    return ProductSerial(
      id: json['id'] as int,
      productId: _asInt(json['product_id']) ?? 0,
      serialNumber: json['serial_number'] as String?,
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
  List<Object?> get props => [id, productId, serialNumber, status];
}
