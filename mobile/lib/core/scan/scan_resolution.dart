import 'package:equatable/equatable.dart';

/// What a scanned code turned out to be (§26, `resolve_barcode`).
///
/// One call answers for all of them, in this order: a product barcode first
/// (the common case), then a serial number, then a location label. That order
/// is the server's and matters — a serial that happens to look like a product
/// barcode still resolves as the product.
enum ScanKind {
  product('product'),
  serial('serial'),
  location('location'),
  unknown('unknown');

  const ScanKind(this.code);

  final String code;

  static ScanKind fromCode(dynamic value) {
    final code = (value ?? '').toString().toLowerCase();
    return ScanKind.values.firstWhere(
      (k) => k.code == code,
      orElse: () => ScanKind.unknown,
    );
  }
}

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

int? _asIntOrNull(dynamic v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

String? _asText(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// The resolved meaning of one scan.
///
/// Deliberately one flat class rather than a sealed hierarchy: the three kinds
/// overlap heavily (a serial scan carries its product too), the server returns
/// one shape, and a screen that only cares "which product is this" should not
/// have to switch on the kind to find out. [kind] is there for the screens that
/// do care — a put-away screen wants a location, a picking screen wants goods.
class ScanResolution extends Equatable {
  const ScanResolution({
    required this.kind,
    required this.barcode,
    this.productId,
    this.janCode,
    this.sku,
    this.name,
    this.category,
    this.status,
    this.trackingMode,
    this.barcodeType,
    this.quantityPerScan,
    this.uom,
    this.baseUom,
    this.isPrimary = false,
    this.serialId,
    this.serialNumber,
    this.serialStatus,
    this.lotId,
    this.lotCode,
    this.expiryDate,
    this.locationId,
    this.locationCode,
    this.locationType,
    this.warehouseId,
    this.binId,
    this.zoneId,
    this.isActive,
    this.pickable,
    this.receivable,
    this.quarantine,
    this.isVirtual,
  });

  final ScanKind kind;

  /// The code as the server matched it — normalized, so it may differ from what
  /// was typed (full-width digits folded, separators dropped, a 12-digit UPC-A
  /// padded to 13).
  final String barcode;

  // Goods (product and serial scans).
  final int? productId;
  final String? janCode;
  final String? sku;
  final String? name;
  final String? category;
  final String? status;
  final String? trackingMode;

  // Product-barcode specifics.
  final String? barcodeType;

  /// How many base units one scan of this code means — 12 for a case code whose
  /// unit converts at 12. Always 1 for a serial, which is one physical unit.
  final int? quantityPerScan;
  final String? uom;
  final String? baseUom;
  final bool isPrimary;

  // Serial specifics.
  final int? serialId;
  final String? serialNumber;
  final String? serialStatus;
  final int? lotId;
  final String? lotCode;
  final DateTime? expiryDate;

  // Location specifics.
  final int? locationId;
  final String? locationCode;
  final String? locationType;
  final int? warehouseId;
  final int? binId;
  final int? zoneId;
  final bool? isActive;
  final bool? pickable;
  final bool? receivable;
  final bool? quarantine;
  final bool? isVirtual;

  bool get isUnknown => kind == ScanKind.unknown;

  /// True when the scan identified goods, whichever way round. A receiving or
  /// picking screen asks this rather than comparing the kind twice.
  bool get isGoods => kind == ScanKind.product || kind == ScanKind.serial;

  /// What one scan adds to a count. A serial is one unit; an unknown code adds
  /// nothing, because nothing has been identified to add.
  int get countedQuantity => switch (kind) {
        ScanKind.product => quantityPerScan ?? 1,
        ScanKind.serial => 1,
        _ => 0,
      };

  factory ScanResolution.fromJson(Map<String, dynamic> json) => ScanResolution(
        kind: ScanKind.fromCode(json['kind']),
        barcode: (json['barcode'] ?? '').toString(),
        productId: _asIntOrNull(json['product_id']),
        janCode: _asText(json['jan_code']),
        sku: _asText(json['sku']),
        name: _asText(json['name']),
        category: _asText(json['category']),
        status: _asText(json['status']),
        trackingMode: _asText(json['tracking_mode']),
        barcodeType: _asText(json['barcode_type']),
        quantityPerScan: json['quantity_per_scan'] == null
            ? null
            : _asInt(json['quantity_per_scan']),
        uom: _asText(json['uom']),
        baseUom: _asText(json['base_uom']),
        isPrimary: json['is_primary'] == true,
        serialId: _asIntOrNull(json['serial_id']),
        serialNumber: _asText(json['serial_number']),
        serialStatus: _asText(json['serial_status']),
        lotId: _asIntOrNull(json['lot_id']),
        lotCode: _asText(json['lot_code']),
        expiryDate: DateTime.tryParse('${json['expiry_date']}'),
        locationId: _asIntOrNull(json['location_id']),
        locationCode: _asText(json['code']),
        locationType: _asText(json['location_type']),
        warehouseId: _asIntOrNull(json['warehouse_id']),
        binId: _asIntOrNull(json['bin_id']),
        zoneId: _asIntOrNull(json['zone_id']),
        isActive: json['is_active'] as bool?,
        pickable: json['pickable'] as bool?,
        receivable: json['receivable'] as bool?,
        quarantine: json['quarantine'] as bool?,
        isVirtual: json['is_virtual'] as bool?,
      );

  @override
  List<Object?> get props => [
        kind,
        barcode,
        productId,
        janCode,
        sku,
        name,
        quantityPerScan,
        uom,
        baseUom,
        serialId,
        serialNumber,
        serialStatus,
        lotId,
        lotCode,
        expiryDate,
        locationId,
        locationCode,
        locationType,
        warehouseId,
        binId,
      ];
}
