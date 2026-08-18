import 'package:equatable/equatable.dart';

/// A warehouse (physical site) in the org. `locationsCount` / `usersCount` come
/// from the backend `withCount`. `is_default` marks the org's primary site.
class Warehouse extends Equatable {
  const Warehouse({
    required this.id,
    required this.name,
    this.code,
    this.description,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.province,
    this.postalCode,
    this.country,
    this.phone,
    this.email,
    this.managerName,
    this.timezone,
    this.currency,
    this.isDefault = false,
    this.isActive = true,
    this.priority = 0,
    this.locationsCount,
    this.usersCount,
  });

  final int id;
  final String name;
  final String? code;
  final String? description;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? province;
  final String? postalCode;
  final String? country;
  final String? phone;
  final String? email;
  final String? managerName;
  final String? timezone;
  final String? currency;
  final bool isDefault;
  final bool isActive;
  final int priority;
  final int? locationsCount;
  final int? usersCount;

  /// Best available short identifier for display in mono type.
  String get displayCode {
    final c = code?.trim();
    if (c != null && c.isNotEmpty) return c;
    return name;
  }

  /// One-line address composed from the parts that are present.
  String get fullAddress {
    final parts = [
      addressLine1,
      addressLine2,
      city,
      province,
      postalCode,
      country,
    ].where((p) => p != null && p.trim().isNotEmpty).map((p) => p!.trim());
    return parts.join(', ');
  }

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      description: json['description'] as String?,
      addressLine1: json['address_line_1'] as String?,
      addressLine2: json['address_line_2'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      managerName: json['manager_name'] as String?,
      timezone: json['timezone'] as String?,
      currency: json['currency'] as String?,
      isDefault: _asBool(json['is_default']) ?? false,
      isActive: _asBool(json['is_active']) ?? true,
      priority: _asInt(json['priority']) ?? 0,
      locationsCount: _asInt(json['locations_count']),
      usersCount: _asInt(json['users_count']),
    );
  }

  static bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  @override
  List<Object?> get props => [id, name, code, isDefault, isActive];
}
