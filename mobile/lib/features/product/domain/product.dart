import 'package:equatable/equatable.dart';

import 'supplier_product_name.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

double? _asDouble(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

String? _asText(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// A unit of measure as `list_products` / `resolve_barcode` return it (0059).
class Uom extends Equatable {
  const Uom({required this.code, required this.name});

  final String code;
  final String name;

  factory Uom.fromJson(Map<String, dynamic> json) => Uom(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [code, name];
}

/// One row of `product_uoms` (0059): how many base units one of this unit is.
/// A box of pens and a box of copier paper are not the same number of pieces,
/// so the factor belongs to the product, never to the unit.
class ProductUom extends Equatable {
  const ProductUom({
    required this.code,
    required this.name,
    required this.conversionFactor,
    required this.isBase,
    this.packageWeightG,
    this.grossWeightG,
    this.packWeightG,
  });

  final String code;
  final String name;
  final double conversionFactor;
  final bool isBase;

  /// The empty packaging of one of these — the inner box, the case (0115).
  final double? packageWeightG;

  /// One whole pack, weighed (0115). Wins over the pieces plus packaging.
  final double? grossWeightG;

  /// What one pack weighs as the server works it out: [grossWeightG] when
  /// known, else the pieces at the product's unit weight plus the packaging.
  /// Null while the product has no unit weight.
  final double? packWeightG;

  factory ProductUom.fromJson(Map<String, dynamic> json) => ProductUom(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        conversionFactor: _asDouble(json['conversion_factor']) ?? 1,
        isBase: json['is_base'] == true,
        packageWeightG: _asDouble(json['package_weight_g']),
        grossWeightG: _asDouble(json['gross_weight_g']),
        packWeightG: _asDouble(json['pack_weight_g']),
      );

  @override
  List<Object?> get props =>
      [code, name, conversionFactor, isBase, packageWeightG, grossWeightG, packWeightG];
}

/// One row of `product_barcodes` (0057): a JAN, an EAN, a case code, an
/// internal SKU label — any of which resolves to the same product.
///
/// `quantityPerScan` is what one scan of *this* code means in base units, so a
/// case code reads 12 where the piece JAN reads 1. Since 0059 it is derived
/// from the unit's conversion when [uom] is set, which is why it is shown
/// beside the unit rather than on its own.
class ProductBarcode extends Equatable {
  const ProductBarcode({
    required this.id,
    required this.barcode,
    required this.barcodeType,
    required this.isPrimary,
    required this.quantityPerScan,
    this.uom,
  });

  final int id;
  final String barcode;
  final String barcodeType;
  final bool isPrimary;
  final int quantityPerScan;
  final String? uom;

  factory ProductBarcode.fromJson(Map<String, dynamic> json) => ProductBarcode(
        id: _asInt(json['id']),
        barcode: (json['barcode'] ?? '').toString(),
        barcodeType: (json['barcode_type'] ?? '').toString(),
        isPrimary: json['is_primary'] == true,
        quantityPerScan: _asInt(json['quantity_per_scan'] ?? 1),
        uom: _asText(json['uom']),
      );

  @override
  List<Object?> get props =>
      [id, barcode, barcodeType, isPrimary, quantityPerScan, uom];
}

/// What a product's tracking mode says must be recorded about it (0057, 0060).
/// The server enforces this; the client shows it so an operator knows before
/// receiving whether a lot or a serial will be asked for.
enum TrackingMode {
  untracked('UNTRACKED'),
  lot('LOT'),
  serial('SERIAL'),
  lotAndSerial('LOT_AND_SERIAL'),
  expiry('EXPIRY');

  const TrackingMode(this.code);

  final String code;

  static TrackingMode fromCode(dynamic value) {
    final code = (value ?? '').toString().toUpperCase();
    return TrackingMode.values.firstWhere(
      (m) => m.code == code,
      orElse: () => TrackingMode.untracked,
    );
  }

  bool get tracksLot =>
      this == TrackingMode.lot ||
      this == TrackingMode.lotAndSerial ||
      this == TrackingMode.expiry;

  bool get tracksSerial =>
      this == TrackingMode.serial || this == TrackingMode.lotAndSerial;
}

/// One row of `list_products` — the product master.
///
/// `id` is the internal identifier the schema has been moving onto since 0058:
/// every stock and history table now carries a nullable `product_id` filled
/// from `jan_code`, and 0057 made the JAN one barcode among several rather than
/// the key. The JAN stays on this model because it is still what the existing
/// stock, receiving and picking paths are keyed by, and because it is what an
/// operator reads off the box.
/// Where a product stands (0120). Only [active] is handled; the rest are
/// kept, with their history, and can be brought back.
enum ProductLifecycle {
  /// 取扱中 — handled as usual.
  active('active'),

  /// 休眠 — not handled for now.
  dormant('dormant'),

  /// 提供終了 — no longer offered.
  discontinued('discontinued'),

  /// 削除済み — taken out of the library; a logical delete, restorable.
  archived('archived');

  const ProductLifecycle(this.wire);
  final String wire;

  static ProductLifecycle? parse(Object? v) =>
      ProductLifecycle.values.where((l) => l.wire == '$v').firstOrNull;
}

/// A product's stock in the warehouses the person can see (0120).
class ProductStock extends Equatable {
  const ProductStock({this.onHand = 0, this.reserved = 0, this.available = 0, this.warehouses = const []});

  final int onHand;
  final int reserved;
  final int available;

  /// Only the warehouses that hold or have reserved some.
  final List<WarehouseStock> warehouses;

  bool get isEmpty => onHand == 0 && reserved == 0;

  factory ProductStock.fromJson(Map<String, dynamic> j) => ProductStock(
        onHand: _asInt(j['on_hand']),
        reserved: _asInt(j['reserved']),
        available: _asInt(j['available']),
        warehouses: [
          for (final w in (j['warehouses'] as List? ?? const []).whereType<Map>())
            WarehouseStock.fromJson(w.cast<String, dynamic>()),
        ],
      );

  @override
  List<Object?> get props => [onHand, reserved, available, warehouses];
}

class WarehouseStock extends Equatable {
  const WarehouseStock({required this.warehouseId, required this.name, this.onHand = 0, this.reserved = 0, this.available = 0});

  final int warehouseId;
  final String name;
  final int onHand;
  final int reserved;
  final int available;

  factory WarehouseStock.fromJson(Map<String, dynamic> j) => WarehouseStock(
        warehouseId: _asInt(j['warehouse_id']),
        name: (j['name'] ?? '').toString(),
        onHand: _asInt(j['on_hand']),
        reserved: _asInt(j['reserved']),
        available: _asInt(j['available']),
      );

  @override
  List<Object?> get props => [warehouseId, name, onHand, reserved, available];
}

/// A supplier that sells the product (0120): by its names for it or its
/// prices.
class ProductSupplierRef extends Equatable {
  const ProductSupplierRef({required this.id, required this.name});

  final int id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// One of the product's attributes (0110/0111) — 色, サイズ, 容量 … — by
/// its name and value, as the product screen lists it (0121).
class ProductPart extends Equatable {
  const ProductPart({required this.key, required this.name, required this.value});

  final String key;
  final String name;
  final String value;

  @override
  List<Object?> get props => [key, name, value];
}

/// `{lang: name}` from a `names` object (0118), empty names left out.
Map<String, String> productNamesFromJson(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, String>{};
  raw.forEach((k, v) {
    final s = v?.toString().trim() ?? '';
    if (s.isNotEmpty) out[k.toString()] = s;
  });
  return out;
}

class Product extends Equatable {
  const Product({
    required this.id,
    required this.janCode,
    required this.name,
    this.nameEn,
    this.names = const {},
    this.sku,
    this.maker,
    this.category,
    this.price,
    this.status = 'active',
    this.lifecycleCode,
    this.lifecycleReason,
    this.stock,
    this.suppliers = const [],
    this.baseName,
    this.unit,
    this.listPrice,
    this.attributes = const [],
    this.imageCount = 0,
    this.trackingMode = TrackingMode.untracked,
    this.pickingRule = 'FEFO',
    this.requiresInspection = false,
    this.baseUom,
    this.uoms = const [],
    this.barcodes = const [],
    this.supplierNames = const [],
    this.unitWeightG,
    this.weightSource,
    this.weightSourceUrl,
    this.weightNote,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String janCode;
  final String name;

  /// The English name (0117), shown on English and Chinese screens and under
  /// the Japanese one on Japanese screens.
  final String? nameEn;

  /// Every name the product has, by language (0118): `ja` is [name], `en`
  /// is [nameEn], and `zh` and any other language are set on their own.
  final Map<String, String> names;
  final String? sku;

  /// Our maker name (0103). With [janCode], [name] and [sku] (our 品番) it is
  /// what whatever a supplier delivers is converted to.
  final String? maker;
  final String? category;
  final double? price;
  final String status;

  /// As stored (0120); read through [lifecycle].
  final String? lifecycleCode;

  /// Why it was made dormant, discontinued or archived.
  final String? lifecycleReason;

  /// Its stock where the person can see (0120); null when not loaded.
  final ProductStock? stock;

  /// Every supplier that sells it (0120).
  final List<ProductSupplierRef> suppliers;

  /// What the name is built from (0111, read since 0121): 品名 without the
  /// maker or attributes, the unit as written, 定価, and the attributes.
  final String? baseName;
  final String? unit;
  final double? listPrice;
  final List<ProductPart> attributes;

  /// How many pictures it has (0109, read since 0122).
  final int imageCount;
  final TrackingMode trackingMode;

  /// §16's default draw order for this product (0074): FIFO/FEFO/LIFO/MANUAL.
  /// A warehouse may override it (`warehouse_products.picking_rule`); this is
  /// the product's own fallback, which `picking_rule_for` and this reader
  /// agree on defaulting to when nothing is set.
  final String pickingRule;

  /// §13's QC gate (0068): true means goods of this product arrive
  /// QC_PENDING rather than OK. A warehouse may override it
  /// (`warehouse_products.requires_inspection`); this is the product's own
  /// default, which `receiving_status_for` falls back to.
  final bool requiresInspection;
  final Uom? baseUom;
  final List<ProductUom> uoms;
  final List<ProductBarcode> barcodes;

  /// What each supplier calls this product (0087).
  final List<SupplierProductName> supplierNames;

  /// One base unit's weight in grams (0115), or null while nobody has
  /// entered or found one.
  final double? unitWeightG;

  /// Where [unitWeightG] came from: `manual`, `web` (with [weightSourceUrl])
  /// or `measured` — weighed here.
  final String? weightSource;
  final String? weightSourceUrl;
  final String? weightNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

  /// Where the product stands. [status] is the older on/off switch and wins
  /// when the two disagree: inactive without a lifecycle reads as dormant.
  ProductLifecycle get lifecycle {
    final l = ProductLifecycle.parse(lifecycleCode);
    if (!isActive) return l == null || l == ProductLifecycle.active ? ProductLifecycle.dormant : l;
    return ProductLifecycle.active;
  }

  /// This product in another lifecycle (for screens and fakes; the server
  /// keeps [status] in step the same way).
  Product withLifecycle(ProductLifecycle l, {String? reason}) => Product(
        id: id, janCode: janCode, name: name, nameEn: nameEn, names: names, sku: sku, maker: maker,
        category: category, price: price,
        status: l == ProductLifecycle.active ? 'active' : 'inactive',
        lifecycleCode: l.wire, lifecycleReason: l == ProductLifecycle.active ? null : reason,
        stock: stock, suppliers: suppliers, baseName: baseName, unit: unit, listPrice: listPrice,
        attributes: attributes, imageCount: imageCount, trackingMode: trackingMode, pickingRule: pickingRule,
        requiresInspection: requiresInspection, baseUom: baseUom, uoms: uoms, barcodes: barcodes,
        supplierNames: supplierNames, unitWeightG: unitWeightG, weightSource: weightSource,
        weightSourceUrl: weightSourceUrl, weightNote: weightNote, createdAt: createdAt, updatedAt: updatedAt,
      );

  /// The pack units beyond the base one — what an operator can actually choose
  /// between when counting or receiving.
  List<ProductUom> get packUoms =>
      uoms.where((u) => !u.isBase).toList(growable: false);

  /// Codes other than the primary one. A product with aliases is a product a
  /// scan can reach more than one way, which is worth showing on the card.
  List<ProductBarcode> get alternateBarcodes =>
      barcodes.where((b) => !b.isPrimary).toList(growable: false);

  static List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => parse(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        nameEn: _asText(json['name_en']),
        names: productNamesFromJson(json['names']),
        sku: _asText(json['sku']),
        maker: _asText(json['maker']),
        category: _asText(json['category']),
        price: _asDouble(json['price']),
        status: (json['status'] ?? 'active').toString(),
        lifecycleCode: _asText(json['lifecycle']),
        lifecycleReason: _asText(json['lifecycle_reason']),
        stock: json['stock'] is Map ? ProductStock.fromJson((json['stock'] as Map).cast<String, dynamic>()) : null,
        suppliers: [
          for (final s in (json['suppliers'] as List? ?? const []).whereType<Map>())
            ProductSupplierRef(id: _asInt(s['id']), name: (s['name'] ?? '').toString()),
        ],
        baseName: _asText(json['base_name']),
        unit: _asText(json['unit']),
        listPrice: _asDouble(json['list_price']),
        attributes: [
          for (final a in (json['attributes'] is List ? json['attributes'] as List : const []).whereType<Map>())
            if (_asText(a['value']) != null)
              ProductPart(
                key: (a['key'] ?? '').toString(),
                name: (a['name'] ?? a['key'] ?? '').toString(),
                value: _asText(a['value'])!,
              ),
        ],
        imageCount: _asInt(json['image_count'] ?? 0),
        trackingMode: TrackingMode.fromCode(json['tracking_mode']),
        pickingRule: (json['picking_rule'] ?? 'FEFO').toString(),
        requiresInspection: json['requires_inspection'] == true,
        baseUom: json['base_uom'] is Map
            ? Uom.fromJson((json['base_uom'] as Map).cast<String, dynamic>())
            : null,
        uoms: _list(json['uoms'], ProductUom.fromJson),
        barcodes: _list(json['barcodes'], ProductBarcode.fromJson),
        supplierNames: _list(json['supplier_names'], SupplierProductName.fromJson),
        unitWeightG: _asDouble(json['unit_weight_g']),
        weightSource: _asText(json['weight_source']),
        weightSourceUrl: _asText(json['weight_source_url']),
        weightNote: _asText(json['weight_note']),
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        updatedAt: DateTime.tryParse('${json['updated_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props => [
        id,
        janCode,
        name,
        nameEn,
        names,
        sku,
        maker,
        category,
        price,
        status,
        lifecycleCode,
        lifecycleReason,
        stock,
        suppliers,
        baseName,
        unit,
        listPrice,
        attributes,
        imageCount,
        trackingMode,
        pickingRule,
        requiresInspection,
        baseUom,
        uoms,
        barcodes,
        unitWeightG,
        weightSource,
        weightSourceUrl,
        weightNote,
      ];
}
