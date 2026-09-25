import 'package:equatable/equatable.dart';

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
  });

  final String code;
  final String name;
  final double conversionFactor;
  final bool isBase;

  factory ProductUom.fromJson(Map<String, dynamic> json) => ProductUom(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        conversionFactor: _asDouble(json['conversion_factor']) ?? 1,
        isBase: json['is_base'] == true,
      );

  @override
  List<Object?> get props => [code, name, conversionFactor, isBase];
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
class Product extends Equatable {
  const Product({
    required this.id,
    required this.janCode,
    required this.name,
    this.sku,
    this.category,
    this.price,
    this.status = 'active',
    this.trackingMode = TrackingMode.untracked,
    this.pickingRule = 'FEFO',
    this.requiresInspection = false,
    this.baseUom,
    this.uoms = const [],
    this.barcodes = const [],
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String janCode;
  final String name;
  final String? sku;
  final String? category;
  final double? price;
  final String status;
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

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
        sku: _asText(json['sku']),
        category: _asText(json['category']),
        price: _asDouble(json['price']),
        status: (json['status'] ?? 'active').toString(),
        trackingMode: TrackingMode.fromCode(json['tracking_mode']),
        pickingRule: (json['picking_rule'] ?? 'FEFO').toString(),
        requiresInspection: json['requires_inspection'] == true,
        baseUom: json['base_uom'] is Map
            ? Uom.fromJson((json['base_uom'] as Map).cast<String, dynamic>())
            : null,
        uoms: _list(json['uoms'], ProductUom.fromJson),
        barcodes: _list(json['barcodes'], ProductBarcode.fromJson),
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        updatedAt: DateTime.tryParse('${json['updated_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props => [
        id,
        janCode,
        name,
        sku,
        category,
        price,
        status,
        trackingMode,
        pickingRule,
        requiresInspection,
        baseUom,
        uoms,
        barcodes,
      ];
}
