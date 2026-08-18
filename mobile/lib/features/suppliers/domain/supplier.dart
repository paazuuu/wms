import 'package:equatable/equatable.dart';

/// A supplier / vendor in the purchasing directory. `fullAddress` is a
/// backend-composed one-line address; `productsCount` is how many products are
/// sourced from this supplier.
class Supplier extends Equatable {
  const Supplier({
    required this.id,
    required this.name,
    this.code,
    this.contactName,
    this.email,
    this.phone,
    this.fullAddress,
    this.website,
    this.paymentTerms,
    this.currency,
    this.notes,
    this.isActive = true,
    this.productsCount,
  });

  final int id;
  final String name;
  final String? code;
  final String? contactName;
  final String? email;
  final String? phone;
  final String? fullAddress;
  final String? website;
  final String? paymentTerms;
  final String? currency;
  final String? notes;
  final bool isActive;
  final int? productsCount;

  /// Best available short identifier for display in mono type.
  String get displayCode {
    final c = code?.trim();
    if (c != null && c.isNotEmpty) return c;
    return name;
  }

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      contactName: json['contact_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      fullAddress: json['full_address'] as String?,
      website: json['website'] as String?,
      paymentTerms: json['payment_terms'] as String?,
      currency: json['currency'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      productsCount: _asInt(json['products_count']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  @override
  List<Object?> get props => [id, name, code, email, isActive];
}
