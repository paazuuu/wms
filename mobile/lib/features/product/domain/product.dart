import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

double? _asDouble(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

/// One row of `list_products` (0032) — the product master, keyed by the same
/// JAN code already threaded through `stock_levels`/`stock_movements`/
/// `bin_stock`, not a new `product_id` foreign key wired into those tables.
class Product extends Equatable {
  const Product({
    required this.id,
    required this.janCode,
    required this.name,
    this.category,
    this.price,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String janCode;
  final String name;
  final String? category;
  final double? price;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        category: json['category'] as String?,
        price: _asDouble(json['price']),
        status: (json['status'] ?? 'active').toString(),
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        updatedAt: DateTime.tryParse('${json['updated_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props => [id, janCode, name, category, price, status];
}
