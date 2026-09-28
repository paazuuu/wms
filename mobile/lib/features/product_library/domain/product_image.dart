import 'package:equatable/equatable.dart';

// The product library (0109): each product's pictures in the company's
// order; the first is the product's face, shown in front of its name
// wherever the product appears.

int _i(dynamic v, [int d = 0]) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? d);
String? _s(dynamic v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

/// Digits only, so a JAN written with hyphens or spaces finds its picture.
String normalizeJanKey(String? jan) => (jan ?? '').replaceAll(RegExp(r'\D'), '');

class ProductImage extends Equatable {
  const ProductImage({
    required this.id,
    required this.productId,
    required this.storagePath,
    this.position = 1,
    this.caption,
    this.contentType,
    this.createdAt,
  });

  final int id;
  final int productId;
  final String storagePath;

  /// 1 is the face.
  final int position;
  final String? caption;
  final String? contentType;
  final DateTime? createdAt;

  bool get isFace => position == 1;

  factory ProductImage.fromJson(Map<String, dynamic> j) => ProductImage(
        id: _i(j['id']),
        productId: _i(j['product_id']),
        storagePath: (j['storage_path'] ?? '').toString(),
        position: _i(j['position'], 1),
        caption: _s(j['caption']),
        contentType: _s(j['content_type']),
        createdAt: DateTime.tryParse('${j['created_at']}'),
      );

  @override
  List<Object?> get props => [id, productId, storagePath, position, caption];
}

/// One product as the library lists it.
class LibraryProduct extends Equatable {
  const LibraryProduct({
    required this.id,
    required this.name,
    this.janCode,
    this.sku,
    this.maker,
    this.category,
    this.facePath,
    this.imageCount = 0,
  });

  final int id;
  final String name;
  final String? janCode;
  final String? sku;
  final String? maker;
  final String? category;

  /// The face's storage path; null when the product has no picture yet.
  final String? facePath;
  final int imageCount;

  factory LibraryProduct.fromJson(Map<String, dynamic> j) => LibraryProduct(
        id: _i(j['id']),
        name: (j['name'] ?? '').toString(),
        janCode: _s(j['jan_code']),
        sku: _s(j['sku']),
        maker: _s(j['maker']),
        category: _s(j['category']),
        facePath: _s(j['storage_path']),
        imageCount: _i(j['image_count']),
      );

  @override
  List<Object?> get props => [id, name, janCode, facePath, imageCount];
}

/// The face of one product, as found by id or JAN.
class ProductFace extends Equatable {
  const ProductFace({required this.productId, this.janCode, required this.storagePath, this.count = 1});

  final int productId;
  final String? janCode;
  final String storagePath;
  final int count;

  factory ProductFace.fromJson(Map<String, dynamic> j) => ProductFace(
        productId: _i(j['product_id']),
        janCode: _s(j['jan_code']),
        storagePath: (j['storage_path'] ?? '').toString(),
        count: _i(j['count'], 1),
      );

  @override
  List<Object?> get props => [productId, janCode, storagePath, count];
}
