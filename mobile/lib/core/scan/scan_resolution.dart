import 'package:equatable/equatable.dart';

import 'scan_context.dart';

/// What a scanned code turned out to be (§26, `resolve_barcode`).
///
/// One call answers for all of them, and the order it tries them in is the scan
/// context's, not a constant — during put-away a code is tried as a location
/// first, during receiving as a receipt. That is why the same string can resolve
/// two ways, and why the server decides rather than the screen.
///
/// [ambiguous] is not a failure: it is the resolver declining to guess. A lot
/// code identifies a lot only within its product, so scanning one with no
/// product in hand can match several — and picking one of them silently is how
/// the wrong lot gets shipped.
enum ScanKind {
  product('product'),
  serial('serial'),
  lot('lot'),
  location('location'),
  receipt('receipt'),
  delivery('delivery'),
  shipment('shipment'),
  task('task'),
  inspection('inspection'),
  ambiguous('ambiguous'),
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
    this.manufactureDate,
    this.isExpired = false,
    this.reconciliationId,
    this.referenceNo,
    this.deliveryPlanId,
    this.deliveryNumber,
    this.supplierName,
    this.shipmentPlanId,
    this.shipmentNumber,
    this.customerName,
    this.carrier,
    this.trackingNumber,
    this.taskType,
    this.pickListId,
    this.inspectionId,
    this.stockCountId,
    this.transferOrderId,
    this.transferNumber,
    this.documentStatus,
    this.candidates = const [],
    this.ambiguityReason,
    this.context,
    this.expected = false,
    this.expectedRank,
    this.contextExpects = const [],
    this.requiresInspection = false,
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

  // Lot specifics.
  final DateTime? manufactureDate;
  final bool isExpired;

  // Documents: a receipt, the delivery note behind it, a shipment.
  final int? reconciliationId;
  final String? referenceNo;
  final int? deliveryPlanId;
  final String? deliveryNumber;
  final String? supplierName;
  final int? shipmentPlanId;
  final String? shipmentNumber;
  final String? customerName;
  final String? carrier;
  final String? trackingNumber;

  // Tasks, from the labels this system prints: PICK-12, QC-3, COUNT-4, TO-9.
  final String? taskType;
  final int? pickListId;
  final int? inspectionId;
  final int? stockCountId;
  final int? transferOrderId;
  final String? transferNumber;

  /// The status of whatever document or task was found. Separate from [status],
  /// which is the *product's* status, because a scan can carry both.
  final String? documentStatus;

  /// Set only when [kind] is [ScanKind.ambiguous]: the things the code could
  /// have meant, for the operator to choose between.
  final List<ScanCandidate> candidates;
  final String? ambiguityReason;

  /// The context the scan was made in, echoed back, and whether what was found
  /// is something this step expects at all.
  final ScanContext? context;

  /// True when the resolved kind is one the context lists. Note this is
  /// membership, not first place: receiving expects a product scan as well as a
  /// receipt. [expectedRank] carries the ordering for screens that want to tell
  /// "exactly what I asked for" from "fair enough, carry on".
  final bool expected;
  final int? expectedRank;
  final List<ScanKind> contextExpects;

  /// True when goods of this product arrive held for QC (§13). A receiving
  /// screen shows it before the operator keys a quantity, so the QC_PENDING
  /// status is not a surprise afterwards.
  final bool requiresInspection;

  bool get isUnknown => kind == ScanKind.unknown;

  /// True when the scan identified goods, whichever way round. A receiving or
  /// picking screen asks this rather than comparing the kind twice.
  bool get isGoods =>
      kind == ScanKind.product || kind == ScanKind.serial || kind == ScanKind.lot;

  /// True when the scan identified a piece of paperwork rather than goods.
  bool get isDocument =>
      kind == ScanKind.receipt ||
      kind == ScanKind.delivery ||
      kind == ScanKind.shipment;

  bool get isTask => kind == ScanKind.task || kind == ScanKind.inspection;

  /// The scan resolved, but not to something this step can use. Distinct from
  /// [isUnknown]: the code is real, it is just the wrong kind of thing to be
  /// holding right now, which is a different sentence to show an operator.
  bool get isOutOfContext => !isUnknown && context != null && !expected;

  /// What one scan adds to a count. A serial is one unit; a lot scan identifies
  /// which lot, not how many of it; an unknown code adds nothing.
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
        manufactureDate: DateTime.tryParse('${json['manufacture_date']}'),
        isExpired: json['is_expired'] == true,
        reconciliationId: _asIntOrNull(json['reconciliation_id']),
        referenceNo: _asText(json['reference_no']),
        deliveryPlanId: _asIntOrNull(json['delivery_plan_id']),
        deliveryNumber: _asText(json['delivery_number']),
        supplierName: _asText(json['supplier_name']),
        shipmentPlanId: _asIntOrNull(json['shipment_plan_id']),
        shipmentNumber: _asText(json['shipment_number']),
        customerName: _asText(json['customer_name']),
        carrier: _asText(json['carrier']),
        trackingNumber: _asText(json['tracking_number']),
        taskType: _asText(json['task_type']),
        pickListId: _asIntOrNull(json['pick_list_id']),
        inspectionId: _asIntOrNull(json['inspection_id']),
        stockCountId: _asIntOrNull(json['stock_count_id']),
        transferOrderId: _asIntOrNull(json['transfer_order_id']),
        transferNumber: _asText(json['transfer_number']),
        // `status` is the product's on a goods scan and the document's
        // otherwise, so both read the same key and only one is ever meaningful.
        documentStatus: _asText(json['status']),
        candidates: (json['candidates'] as List?)
                ?.whereType<Map>()
                .map((c) => ScanCandidate.fromJson(c.cast<String, dynamic>()))
                .toList() ??
            const [],
        ambiguityReason: _asText(json['reason']),
        context: ScanContext.fromCode(json['context']),
        expected: json['expected'] == true,
        expectedRank: _asIntOrNull(json['expected_rank']),
        contextExpects: (json['context_expects'] as List?)
                ?.map(ScanKind.fromCode)
                .toList() ??
            const [],
        requiresInspection: json['requires_inspection'] == true,
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
        reconciliationId,
        referenceNo,
        deliveryPlanId,
        shipmentPlanId,
        taskType,
        pickListId,
        inspectionId,
        stockCountId,
        transferOrderId,
        candidates,
        context,
        expected,
        expectedRank,
        requiresInspection,
      ];
}

/// One thing a code could have meant, when it could have meant several.
class ScanCandidate extends Equatable {
  const ScanCandidate({
    this.lotId,
    this.lotCode,
    this.productId,
    this.janCode,
    this.name,
    this.expiryDate,
  });

  final int? lotId;
  final String? lotCode;
  final int? productId;
  final String? janCode;
  final String? name;
  final DateTime? expiryDate;

  factory ScanCandidate.fromJson(Map<String, dynamic> json) => ScanCandidate(
        lotId: _asIntOrNull(json['lot_id']),
        lotCode: _asText(json['lot_code']),
        productId: _asIntOrNull(json['product_id']),
        janCode: _asText(json['jan_code']),
        name: _asText(json['name']),
        expiryDate: DateTime.tryParse('${json['expiry_date']}'),
      );

  @override
  List<Object?> get props => [lotId, lotCode, productId, janCode, name, expiryDate];
}
