import 'package:equatable/equatable.dart';

/// A storage location (bin / shelf / zone) in the warehouse. `fullLocation` is
/// a backend-composed label (e.g. "A-12-3"); `productsCount` is how many
/// products are assigned to it.
class Location extends Equatable {
  const Location({
    required this.id,
    required this.name,
    this.code,
    this.description,
    this.aisle,
    this.shelf,
    this.bin,
    this.fullLocation,
    this.isActive = true,
    this.productsCount,
  });

  final int id;
  final String name;
  final String? code;
  final String? description;
  final String? aisle;
  final String? shelf;
  final String? bin;
  final String? fullLocation;
  final bool isActive;
  final int? productsCount;

  /// Best available short identifier for display in mono type.
  String get displayCode {
    final full = fullLocation?.trim();
    if (full != null && full.isNotEmpty) return full;
    final c = code?.trim();
    if (c != null && c.isNotEmpty) return c;
    return name;
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      description: json['description'] as String?,
      aisle: json['aisle'] as String?,
      shelf: json['shelf'] as String?,
      bin: json['bin'] as String?,
      fullLocation: json['full_location'] as String?,
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
  List<Object?> get props => [id, name, code, fullLocation, isActive];
}
