import 'package:equatable/equatable.dart';

/// A product/SKU as returned by the backend `ProductResource`. Only the fields
/// the mobile lookup UI needs are modelled; the API returns more.
class Product extends Equatable {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    this.description,
    this.barcode,
    this.stock,
    this.totalStock,
    this.minStock,
    this.currency,
    this.price,
    this.sellingPrice,
    this.isActive = true,
    this.isLowStock = false,
    this.isOutOfStock = false,
    this.hasVariants = false,
    this.categoryName,
    this.locationName,
    this.thumbnail,
  });

  final int id;
  final String sku;
  final String name;
  final String? description;
  final String? barcode;

  /// On-hand stock for the primary/default location.
  final int? stock;

  /// Stock across every location/variant.
  final int? totalStock;
  final int? minStock;

  final String? currency;
  final String? price;
  final String? sellingPrice;

  final bool isActive;
  final bool isLowStock;
  final bool isOutOfStock;
  final bool hasVariants;

  final String? categoryName;
  final String? locationName;
  final String? thumbnail;

  /// Preferred stock figure to surface in the UI.
  int get displayStock => totalStock ?? stock ?? 0;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      sku: json['sku'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      barcode: json['barcode'] as String?,
      stock: _asInt(json['stock']),
      totalStock: _asInt(json['total_stock']),
      minStock: _asInt(json['min_stock']),
      currency: json['currency'] as String?,
      price: _asPriceString(json['price']),
      sellingPrice: _asPriceString(json['selling_price']),
      isActive: json['is_active'] as bool? ?? true,
      isLowStock: json['is_low_stock'] as bool? ?? false,
      isOutOfStock: json['is_out_of_stock'] as bool? ?? false,
      hasVariants: json['has_variants'] as bool? ?? false,
      categoryName: _nestedName(json['category']),
      locationName: _nestedName(json['location']),
      thumbnail: json['thumbnail'] as String?,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  /// Prices arrive as strings ("19.99") or numbers depending on the field.
  static String? _asPriceString(dynamic value) {
    if (value == null) return null;
    return '$value';
  }

  /// Category/location come as `{ id, name, ... }` when loaded, else null.
  static String? _nestedName(dynamic value) {
    if (value is Map<String, dynamic>) return value['name'] as String?;
    return null;
  }

  @override
  List<Object?> get props => [id, sku, name, barcode, totalStock, stock];
}
