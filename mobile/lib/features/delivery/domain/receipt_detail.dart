import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

int? _asIntOrNull(dynamic v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

String? _asText(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// One parcel as it was received, read back from `receipt_detail` (§12, 0067).
///
/// This is the read side of what the parcel sheet records — and it is what makes
/// the Item level worth having: a week later, "which lot did that delivery bring"
/// is answerable without asking whoever was on the dock.
class ReceiptItem extends Equatable {
  const ReceiptItem({
    required this.id,
    required this.quantity,
    this.lotId,
    this.lotCode,
    this.expiry,
    this.serialId,
    this.serialNumber,
    this.locationId,
    this.locationCode,
    this.binId,
    this.statusCode = 'OK',
    this.statusName,
    this.countsAvailable = true,
    this.movementId,
    this.note,
    this.createdAt,
  });

  final int id;
  final int quantity;
  final int? lotId;
  final String? lotCode;
  final DateTime? expiry;
  final int? serialId;
  final String? serialNumber;
  final int? locationId;
  final String? locationCode;
  final int? binId;
  final String statusCode;
  final String? statusName;
  final bool countsAvailable;

  /// The ledger row this parcel posted. Its presence is the whole §5 argument:
  /// the stock came from the movement, and this row only says where the movement
  /// came from — so nothing is counted twice.
  final int? movementId;
  final String? note;
  final DateTime? createdAt;

  /// True for a parcel the operator did not attribute to a lot or serial — the
  /// implicit remainder the server posts. Shown as such rather than as a blank.
  bool get isUnattributed =>
      lotId == null && serialId == null && (lotCode == null);

  bool get isHeld => !countsAvailable;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        id: _asInt(json['receipt_item_id']),
        quantity: _asInt(json['quantity']),
        lotId: _asIntOrNull(json['lot_id']),
        lotCode: _asText(json['lot_code']),
        expiry: DateTime.tryParse('${json['expiry']}'),
        serialId: _asIntOrNull(json['serial_id']),
        serialNumber: _asText(json['serial_number']),
        locationId: _asIntOrNull(json['location_id']),
        locationCode: _asText(json['location_code']),
        binId: _asIntOrNull(json['bin_id']),
        statusCode: _asText(json['status_code']) ?? 'OK',
        statusName: _asText(json['status_name']),
        countsAvailable: json['counts_available'] != false,
        movementId: _asIntOrNull(json['movement_id']),
        note: _asText(json['note']),
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props =>
      [id, quantity, lotId, serialId, statusCode, locationId, movementId];
}

/// One line of a receipt: the ordered line it answers, and the parcels that
/// arrived against it.
class ReceiptLine extends Equatable {
  const ReceiptLine({
    required this.id,
    required this.janCode,
    required this.plannedQuantity,
    required this.actualQuantity,
    required this.status,
    this.productId,
    this.productName,
    this.items = const [],
  });

  final int id;
  final String janCode;
  final int? productId;
  final String? productName;
  final int plannedQuantity;
  final int actualQuantity;

  /// matched / shortfall / over / unexpected, as receiving worked it out.
  final String status;
  final List<ReceiptItem> items;

  int get parcelledQuantity => items.fold(0, (sum, i) => sum + i.quantity);

  /// How much of this line is held and cannot ship — the figure that explains a
  /// receipt whose goods are on hand and unusable.
  int get heldQuantity =>
      items.where((i) => i.isHeld).fold(0, (sum, i) => sum + i.quantity);

  int get difference => actualQuantity - plannedQuantity;

  String get title => productName?.isNotEmpty == true ? productName! : janCode;

  factory ReceiptLine.fromJson(Map<String, dynamic> json) => ReceiptLine(
        id: _asInt(json['line_id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productId: _asIntOrNull(json['product_id']),
        productName: _asText(json['product_name']),
        plannedQuantity: _asInt(json['planned_quantity']),
        actualQuantity: _asInt(json['actual_quantity']),
        status: (json['status'] ?? '').toString(),
        items: (json['items'] as List?)
                ?.whereType<Map>()
                .map((e) => ReceiptItem.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props =>
      [id, janCode, plannedQuantity, actualQuantity, status, items];
}

/// A receipt at all three of §12's levels: the delivery, its lines, their
/// parcels (0067).
class ReceiptDetail extends Equatable {
  const ReceiptDetail({
    required this.reconciliationId,
    this.deliveryPlanId,
    this.deliveryNumber,
    this.warehouseId,
    this.supplierName,
    this.referenceNo,
    this.noteReference,
    this.status = '',
    this.createdAt,
    this.lines = const [],
    this.unlinkedItems = const [],
  });

  final int reconciliationId;
  final int? deliveryPlanId;
  final String? deliveryNumber;
  final int? warehouseId;
  final String? supplierName;
  final String? referenceNo;
  final String? noteReference;
  final String status;
  final DateTime? createdAt;
  final List<ReceiptLine> lines;

  /// Parcels that belong to no line — an unexpected JAN, say. Carried separately
  /// because otherwise they would vanish from this read entirely, and a carton
  /// nobody ordered is exactly the thing you want to see.
  final List<ReceiptItem> unlinkedItems;

  int get totalUnits =>
      lines.fold(0, (sum, l) => sum + l.actualQuantity) +
      unlinkedItems.fold(0, (sum, i) => sum + i.quantity);

  int get heldUnits =>
      lines.fold(0, (sum, l) => sum + l.heldQuantity) +
      unlinkedItems.where((i) => i.isHeld).fold(0, (sum, i) => sum + i.quantity);

  bool get hasHeldStock => heldUnits > 0;

  factory ReceiptDetail.fromJson(Map<String, dynamic> json) => ReceiptDetail(
        reconciliationId: _asInt(json['reconciliation_id']),
        deliveryPlanId: _asIntOrNull(json['delivery_plan_id']),
        deliveryNumber: _asText(json['delivery_number']),
        warehouseId: _asIntOrNull(json['warehouse_id']),
        supplierName: _asText(json['supplier_name']),
        referenceNo: _asText(json['reference_no']),
        noteReference: _asText(json['note_reference']),
        status: (json['status'] ?? '').toString(),
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        lines: (json['lines'] as List?)
                ?.whereType<Map>()
                .map((e) => ReceiptLine.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        unlinkedItems: (json['unlinked_items'] as List?)
                ?.whereType<Map>()
                .map((e) => ReceiptItem.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [reconciliationId, status, lines, unlinkedItems];
}

/// One row of `lot_provenance` (0067): which delivery brought a lot in.
class LotProvenance extends Equatable {
  const LotProvenance({
    required this.receiptItemId,
    required this.quantity,
    this.receivedAt,
    this.reconciliationId,
    this.referenceNo,
    this.deliveryNumber,
    this.supplierName,
    this.warehouseId,
    this.lotId,
    this.lotCode,
    this.expiry,
    this.serialNumber,
    this.locationCode,
    this.statusCode = 'OK',
  });

  final int receiptItemId;
  final int quantity;
  final DateTime? receivedAt;
  final int? reconciliationId;
  final String? referenceNo;
  final String? deliveryNumber;
  final String? supplierName;
  final int? warehouseId;
  final int? lotId;
  final String? lotCode;
  final DateTime? expiry;
  final String? serialNumber;
  final String? locationCode;
  final String statusCode;

  factory LotProvenance.fromJson(Map<String, dynamic> json) => LotProvenance(
        receiptItemId: _asInt(json['receipt_item_id']),
        quantity: _asInt(json['quantity']),
        receivedAt: DateTime.tryParse('${json['received_at']}')?.toLocal(),
        reconciliationId: _asIntOrNull(json['reconciliation_id']),
        referenceNo: _asText(json['reference_no']),
        deliveryNumber: _asText(json['delivery_number']),
        supplierName: _asText(json['supplier_name']),
        warehouseId: _asIntOrNull(json['warehouse_id']),
        lotId: _asIntOrNull(json['lot_id']),
        lotCode: _asText(json['lot_code']),
        expiry: DateTime.tryParse('${json['expiry']}'),
        serialNumber: _asText(json['serial_number']),
        locationCode: _asText(json['location_code']),
        statusCode: _asText(json['status_code']) ?? 'OK',
      );

  @override
  List<Object?> get props =>
      [receiptItemId, quantity, lotId, deliveryNumber, statusCode];
}
