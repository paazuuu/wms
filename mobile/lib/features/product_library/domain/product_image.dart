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

// ---------------------------------------------------------------------------
// How each supplier calls the product (0110)
// ---------------------------------------------------------------------------

/// One of our product attributes: 色, サイズ, 容量, …
class ProductAttributeDef extends Equatable {
  const ProductAttributeDef({required this.id, required this.key, required this.name, this.unit, this.active = true});

  final int id;
  final String key;
  final String name;
  final String? unit;
  final bool active;

  factory ProductAttributeDef.fromJson(Map<String, dynamic> j) => ProductAttributeDef(
        id: _i(j['id'] ?? j['attribute_id']),
        key: (j['key'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        unit: _s(j['unit']),
        active: j['status'] != 'inactive',
      );

  @override
  List<Object?> get props => [id, key, name, unit, active];
}

/// Our value of one attribute for this product.
class ProductAttributeValue extends Equatable {
  const ProductAttributeValue({required this.attribute, this.value});

  final ProductAttributeDef attribute;
  final String? value;

  factory ProductAttributeValue.fromJson(Map<String, dynamic> j) =>
      ProductAttributeValue(attribute: ProductAttributeDef.fromJson(j), value: _s(j['value']));

  @override
  List<Object?> get props => [attribute, value];
}

/// Every spelling of one field a supplier has used for this product.
class SupplierWriting extends Equatable {
  const SupplierWriting({required this.field, this.values = const [], this.seenCount = 0, this.confirmed = false});

  /// jan / maker / name / code
  final String field;
  final List<String> values;
  final int seenCount;
  final bool confirmed;

  factory SupplierWriting.fromJson(Map<String, dynamic> j) => SupplierWriting(
        field: (j['field'] ?? '').toString(),
        values: [for (final v in (j['raw_values'] as List? ?? const [])) v.toString()],
        seenCount: _i(j['seen_count']),
        confirmed: j['confirmed'] == true,
      );

  @override
  List<Object?> get props => [field, values, seenCount, confirmed];
}

/// How a supplier heads and writes one attribute of this product, and what
/// that means in ours.
class SupplierAttribute extends Equatable {
  const SupplierAttribute({
    required this.attributeId,
    required this.key,
    required this.name,
    required this.rawValue,
    this.rawName,
    this.ourValue,
    this.seenCount = 0,
  });

  final int attributeId;
  final String key;

  /// Our name for the attribute.
  final String name;
  final String? rawName;
  final String rawValue;
  final String? ourValue;
  final int seenCount;

  /// The supplier's word already means something else in ours ("BK" → "黒").
  bool get translated => ourValue != null && ourValue != rawValue;

  factory SupplierAttribute.fromJson(Map<String, dynamic> j) => SupplierAttribute(
        attributeId: _i(j['attribute_id']),
        key: (j['key'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        rawName: _s(j['raw_name']),
        rawValue: (j['raw_value'] ?? '').toString(),
        ourValue: _s(j['our_value']),
        seenCount: _i(j['seen_count']),
      );

  @override
  List<Object?> get props => [attributeId, rawName, rawValue, ourValue];
}

/// One supplier's way of calling the product: its name, 品番, JAN and maker
/// for it, every spelling seen, and its attributes.
class SupplierProfile extends Equatable {
  const SupplierProfile({
    required this.supplierId,
    required this.supplierName,
    this.name,
    this.code,
    this.janCode,
    this.maker,
    this.note,
    this.writings = const [],
    this.attributes = const [],
  });

  final int supplierId;
  final String supplierName;
  final String? name;
  final String? code;
  final String? janCode;
  final String? maker;
  final String? note;
  final List<SupplierWriting> writings;
  final List<SupplierAttribute> attributes;

  factory SupplierProfile.fromJson(Map<String, dynamic> j) => SupplierProfile(
        supplierId: _i(j['supplier_id']),
        supplierName: (j['supplier_name'] ?? '').toString(),
        name: _s(j['name']),
        code: _s(j['code']),
        janCode: _s(j['jan_code']),
        maker: _s(j['maker']),
        note: _s(j['note']),
        writings: [
          for (final w in (j['writings'] as List? ?? const []))
            if (w is Map) SupplierWriting.fromJson(w.cast<String, dynamic>()),
        ],
        attributes: [
          for (final a in (j['attributes'] as List? ?? const []))
            if (a is Map) SupplierAttribute.fromJson(a.cast<String, dynamic>()),
        ],
      );

  @override
  List<Object?> get props => [supplierId, name, code, janCode, maker, writings, attributes];
}

/// Everything about how this product is called: ours and each supplier's.
class ProductProfile extends Equatable {
  const ProductProfile({
    required this.productId,
    required this.name,
    this.janCode,
    this.sku,
    this.maker,
    this.attributes = const [],
    this.suppliers = const [],
  });

  final int productId;
  final String name;
  final String? janCode;
  final String? sku;
  final String? maker;
  final List<ProductAttributeValue> attributes;
  final List<SupplierProfile> suppliers;

  factory ProductProfile.fromJson(Map<String, dynamic> j) {
    final p = (j['product'] as Map? ?? const {}).cast<String, dynamic>();
    return ProductProfile(
      productId: _i(p['id']),
      name: (p['name'] ?? '').toString(),
      janCode: _s(p['jan_code']),
      sku: _s(p['sku']),
      maker: _s(p['maker']),
      attributes: [
        for (final a in (j['attributes'] as List? ?? const []))
          if (a is Map) ProductAttributeValue.fromJson(a.cast<String, dynamic>()),
      ],
      suppliers: [
        for (final s in (j['suppliers'] as List? ?? const []))
          if (s is Map) SupplierProfile.fromJson(s.cast<String, dynamic>()),
      ],
    );
  }

  @override
  List<Object?> get props => [productId, name, attributes, suppliers];
}
