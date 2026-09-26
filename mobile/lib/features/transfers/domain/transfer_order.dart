import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
int? _asIntOrNull(dynamic v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

/// Lifecycle of a transfer order (spec §16), verbatim from the state machine
/// there: DRAFT → PENDING_APPROVAL → APPROVED → PICKING → IN_TRANSIT →
/// RECEIVING → COMPLETED, with REJECTED off PENDING_APPROVAL and CANCELLED
/// off anything before stock actually leaves the source.
enum TransferStatus {
  draft('DRAFT'),
  pendingApproval('PENDING_APPROVAL'),
  approved('APPROVED'),
  picking('PICKING'),
  inTransit('IN_TRANSIT'),
  receiving('RECEIVING'),
  completed('COMPLETED'),

  /// Crossed a border to a warehouse that does not receive cross-border
  /// stock: gone from this system the moment it left the source (0087).
  exported('EXPORTED'),
  rejected('REJECTED'),
  cancelled('CANCELLED');

  const TransferStatus(this.wire);
  final String wire;

  static TransferStatus parse(String? v) => switch (v) {
        'PENDING_APPROVAL' => TransferStatus.pendingApproval,
        'APPROVED' => TransferStatus.approved,
        'PICKING' => TransferStatus.picking,
        'IN_TRANSIT' => TransferStatus.inTransit,
        'RECEIVING' => TransferStatus.receiving,
        'COMPLETED' => TransferStatus.completed,
        'EXPORTED' => TransferStatus.exported,
        'REJECTED' => TransferStatus.rejected,
        'CANCELLED' => TransferStatus.cancelled,
        _ => TransferStatus.draft,
      };

  bool get isCancellable =>
      this == draft || this == pendingApproval || this == approved || this == picking;
}

/// A short pick and a transit loss are both recorded as their own number,
/// never silently corrected to what was planned (spec §10) — so both
/// quantities and both variances are nullable by design, the same shape as a
/// pick task or a count line.
class TransferLine extends Equatable {
  const TransferLine({
    required this.id,
    required this.janCode,
    this.productName = '',
    this.sourceProductName,
    required this.requestedQuantity,
    this.pickedQuantity,
    this.pickVariance,
    this.receivedQuantity,
    this.receiveVariance,
  });

  final int id;
  final String janCode;
  final String productName;

  /// What the request called it, when that differs from our product name.
  final String? sourceProductName;
  final int requestedQuantity;
  final int? pickedQuantity;
  final int? pickVariance;
  final int? receivedQuantity;
  final int? receiveVariance;

  bool get isPicked => pickedQuantity != null;
  bool get isReceived => receivedQuantity != null;

  factory TransferLine.fromJson(Map<String, dynamic> json) => TransferLine(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productName: json['product_name'] as String? ?? '',
        sourceProductName: json['source_product_name'] as String?,
        requestedQuantity: _asInt(json['requested_quantity']),
        pickedQuantity: _asIntOrNull(json['picked_quantity']),
        pickVariance: _asIntOrNull(json['pick_variance']),
        receivedQuantity: _asIntOrNull(json['received_quantity']),
        receiveVariance: _asIntOrNull(json['receive_variance']),
      );

  @override
  List<Object?> get props =>
      [id, janCode, requestedQuantity, pickedQuantity, receivedQuantity];
}

class TransferOrder extends Equatable {
  const TransferOrder({
    required this.id,
    this.transferNumber,
    required this.sourceWarehouseId,
    this.sourceWarehouseName,
    required this.destinationWarehouseId,
    this.destinationWarehouseName,
    this.status = TransferStatus.draft,
    this.note,
    this.createdAt,
    this.shippedAt,
    this.receivedAt,
    this.lines = const [],
    this.lineCount,
    this.sourceCountryCode,
    this.destinationCountryCode,
    this.destinationAddress,
    this.destinationPhone,
    this.crossBorder = false,
    this.exports = false,
    this.exportedAt,
  });

  final int id;
  final String? transferNumber;
  final int sourceWarehouseId;
  final String? sourceWarehouseName;
  final int destinationWarehouseId;
  final String? destinationWarehouseName;
  final TransferStatus status;
  final String? note;
  final DateTime? createdAt;
  final DateTime? shippedAt;
  final DateTime? receivedAt;
  final List<TransferLine> lines;
  final int? lineCount;
  final String? sourceCountryCode;
  final String? destinationCountryCode;
  final String? destinationAddress;
  final String? destinationPhone;

  /// The two warehouses are in different countries.
  final bool crossBorder;

  /// Crossing the border takes the goods out of this system: the destination
  /// has not opted in to receiving them (0087).
  final bool exports;
  final DateTime? exportedAt;

  int get totalLines => lines.isNotEmpty ? lines.length : (lineCount ?? 0);
  int get pickedLines => lines.where((l) => l.isPicked).length;
  int get unpickedLines => lines.where((l) => !l.isPicked).length;
  int get receivedLines => lines.where((l) => l.isReceived).length;
  int get unreceivedLines => lines.where((l) => !l.isReceived).length;

  factory TransferOrder.fromJson(Map<String, dynamic> json) => TransferOrder(
        id: _asInt(json['id']),
        transferNumber: json['transfer_number'] as String?,
        sourceWarehouseId: _asInt(json['source_warehouse_id']),
        sourceWarehouseName: json['source_warehouse_name'] as String?,
        destinationWarehouseId: _asInt(json['destination_warehouse_id']),
        destinationWarehouseName: json['destination_warehouse_name'] as String?,
        status: TransferStatus.parse(json['status'] as String?),
        note: json['note'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        shippedAt: DateTime.tryParse('${json['shipped_at']}')?.toLocal(),
        receivedAt: DateTime.tryParse('${json['received_at']}')?.toLocal(),
        lines: (json['lines'] as List?)
                ?.whereType<Map>()
                .map((e) => TransferLine.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        lineCount: _asIntOrNull(json['line_count']),
        sourceCountryCode: json['source_country_code'] as String?,
        destinationCountryCode: json['destination_country_code'] as String?,
        destinationAddress: json['destination_address'] as String?,
        destinationPhone: json['destination_phone'] as String?,
        crossBorder: json['cross_border'] == true,
        exports: json['exports'] == true,
        exportedAt: DateTime.tryParse('${json['exported_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props => [id, status, lines, lineCount, crossBorder, exports];
}

/// What completing receiving actually changed.
class TransferReceiveSummary extends Equatable {
  const TransferReceiveSummary({
    required this.lines,
    required this.pickedUnits,
    required this.receivedUnits,
    required this.lossLines,
  });

  final int lines;
  final int pickedUnits;
  final int receivedUnits;
  final int lossLines;

  factory TransferReceiveSummary.fromJson(Map<String, dynamic> json) =>
      TransferReceiveSummary(
        lines: _asInt(json['lines']),
        pickedUnits: _asInt(json['picked_units']),
        receivedUnits: _asInt(json['received_units']),
        lossLines: _asInt(json['loss_lines']),
      );

  @override
  List<Object?> get props => [lines, pickedUnits, receivedUnits, lossLines];
}
