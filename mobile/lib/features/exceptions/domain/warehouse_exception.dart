import 'package:equatable/equatable.dart';

int? _asIntOrNull(dynamic v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

String? _asText(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// How much someone has to care. The server orders the list by this, so the
/// screen does not sort — it only needs to colour.
enum ExceptionSeverity {
  blocker('BLOCKER'),
  warning('WARNING'),
  info('INFO');

  const ExceptionSeverity(this.code);

  final String code;

  static ExceptionSeverity fromCode(dynamic value) {
    final code = (value ?? '').toString().toUpperCase();
    return ExceptionSeverity.values.firstWhere(
      (s) => s.code == code,
      orElse: () => ExceptionSeverity.warning,
    );
  }
}

/// Where an exception sits in its life. OPEN and ACKNOWLEDGED are both open —
/// acknowledging is "I have seen it", not "it is dealt with" — which is why the
/// server's open list includes both.
enum ExceptionStatus {
  open('OPEN'),
  acknowledged('ACKNOWLEDGED'),
  resolved('RESOLVED'),
  cancelled('CANCELLED');

  const ExceptionStatus(this.code);

  final String code;

  bool get isOpen => this == ExceptionStatus.open || this == ExceptionStatus.acknowledged;

  static ExceptionStatus fromCode(dynamic value) {
    final code = (value ?? '').toString().toUpperCase();
    return ExceptionStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => ExceptionStatus.open,
    );
  }
}

/// What was decided. Three of these mean someone did something to the goods, and
/// the server refuses them without a note — see [needsNote].
enum ExceptionResolution {
  accepted('ACCEPTED'),
  supplierClaim('SUPPLIER_CLAIM'),
  returned('RETURNED'),
  scrapped('SCRAPPED'),
  corrected('CORRECTED'),
  recounted('RECOUNTED'),
  noAction('NO_ACTION');

  const ExceptionResolution(this.code);

  final String code;

  /// The server enforces this too (0071). Asking for the note up front turns a
  /// refusal into a form field.
  bool get needsNote =>
      this == ExceptionResolution.returned ||
      this == ExceptionResolution.scrapped ||
      this == ExceptionResolution.corrected;

  static ExceptionResolution? fromCode(dynamic value) {
    final code = (value ?? '').toString().toUpperCase();
    if (code.isEmpty) return null;
    for (final r in ExceptionResolution.values) {
      if (r.code == code) return r;
    }
    return null;
  }
}

/// One kind of thing that can go wrong, as `list_exception_types` returns it
/// (0071) — the vocabulary `raise_exception` picks from. The server orders
/// these by its own `sort_order`, so the list is shown in that order rather
/// than sorted again client-side.
class ExceptionType extends Equatable {
  const ExceptionType({
    required this.code,
    required this.name,
    required this.category,
    required this.severity,
    this.requiresResolution = true,
  });

  final String code;
  final String name;
  final String category;
  final ExceptionSeverity severity;
  final bool requiresResolution;

  factory ExceptionType.fromJson(Map<String, dynamic> json) => ExceptionType(
        code: (json['code'] ?? '').toString(),
        name: _asText(json['name']) ?? (json['code'] ?? '').toString(),
        category: (json['category'] ?? 'OTHER').toString(),
        severity: ExceptionSeverity.fromCode(json['severity']),
        requiresResolution: json['requires_resolution'] != false,
      );

  @override
  List<Object?> get props => [code, category, severity];
}

/// One thing that went wrong, as `open_exceptions` returns it (0071).
class WarehouseException extends Equatable {
  const WarehouseException({
    required this.id,
    required this.exceptionType,
    required this.exceptionName,
    required this.category,
    required this.severity,
    required this.status,
    this.requiresResolution = true,
    this.warehouseId,
    this.reconciliationId,
    this.reconciliationLineId,
    this.receiptItemId,
    this.inspectionId,
    this.productId,
    this.janCode,
    this.productName,
    this.lotId,
    this.lotCode,
    this.expiryDate,
    this.quantity,
    this.note,
    this.referenceNo,
    this.deliveryNumber,
    this.supplierName,
    this.resolution,
    this.resolutionNote,
    this.createdAt,
    this.acknowledgedAt,
    this.resolvedAt,
  });

  final int id;
  final String exceptionType;

  /// The server's own label, already in the operator's language. Not looked up
  /// client-side: the vocabulary is data (`exception_types`), and a code the app
  /// has never heard of still has to display as something.
  final String exceptionName;
  final String category;
  final ExceptionSeverity severity;
  final ExceptionStatus status;
  final bool requiresResolution;

  final int? warehouseId;
  final int? reconciliationId;
  final int? reconciliationLineId;
  final int? receiptItemId;
  final int? inspectionId;
  final int? productId;
  final String? janCode;
  final String? productName;
  final int? lotId;
  final String? lotCode;
  final DateTime? expiryDate;
  final int? quantity;
  final String? note;

  final String? referenceNo;
  final String? deliveryNumber;
  final String? supplierName;

  final ExceptionResolution? resolution;
  final String? resolutionNote;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;

  bool get isOpen => status.isOpen;
  bool get isBlocker => severity == ExceptionSeverity.blocker;

  /// Something can be acknowledged only once, and only while it is untouched.
  bool get canAcknowledge => status == ExceptionStatus.open;

  /// An INFO exception that needs no resolution can still be closed, but the
  /// screen should not push for it.
  bool get canResolve => status.isOpen;

  /// Whether this exception points at a delivery someone can open. A QC failure
  /// raised against an inspection does too, via [inspectionId].
  bool get hasSource => reconciliationId != null || inspectionId != null;

  factory WarehouseException.fromJson(Map<String, dynamic> json) =>
      WarehouseException(
        id: _asIntOrNull(json['exception_id']) ?? 0,
        exceptionType: (json['exception_type'] ?? '').toString(),
        exceptionName:
            _asText(json['exception_name']) ?? (json['exception_type'] ?? '').toString(),
        category: (json['category'] ?? 'OTHER').toString(),
        severity: ExceptionSeverity.fromCode(json['severity']),
        status: ExceptionStatus.fromCode(json['status']),
        requiresResolution: json['requires_resolution'] != false,
        warehouseId: _asIntOrNull(json['warehouse_id']),
        reconciliationId: _asIntOrNull(json['reconciliation_id']),
        reconciliationLineId: _asIntOrNull(json['reconciliation_line_id']),
        receiptItemId: _asIntOrNull(json['receipt_item_id']),
        inspectionId: _asIntOrNull(json['inspection_id']),
        productId: _asIntOrNull(json['product_id']),
        janCode: _asText(json['jan_code']),
        productName: _asText(json['product_name']),
        lotId: _asIntOrNull(json['lot_id']),
        lotCode: _asText(json['lot_code']),
        expiryDate: DateTime.tryParse('${json['expiry_date']}'),
        quantity: _asIntOrNull(json['quantity']),
        note: _asText(json['note']),
        referenceNo: _asText(json['reference_no']),
        deliveryNumber: _asText(json['delivery_number']),
        supplierName: _asText(json['supplier_name']),
        resolution: ExceptionResolution.fromCode(json['resolution']),
        resolutionNote: _asText(json['resolution_note']),
        createdAt: DateTime.tryParse('${json['created_at']}'),
        acknowledgedAt: DateTime.tryParse('${json['acknowledged_at']}'),
        resolvedAt: DateTime.tryParse('${json['resolved_at']}'),
      );

  @override
  List<Object?> get props => [
        id,
        exceptionType,
        severity,
        status,
        quantity,
        janCode,
        lotCode,
        reconciliationId,
        inspectionId,
        resolution,
      ];
}

/// `exception_summary` (0071): the two numbers a dashboard tile needs, plus the
/// breakdown behind them.
class ExceptionSummary extends Equatable {
  const ExceptionSummary({
    this.open = 0,
    this.blockers = 0,
    this.byType = const [],
  });

  final int open;
  final int blockers;
  final List<ExceptionTypeCount> byType;

  /// Nothing open is the state worth showing differently: an empty list is good
  /// news, and should read as good news rather than as a failed load.
  bool get isClear => open == 0;

  factory ExceptionSummary.fromJson(Map<String, dynamic> json) => ExceptionSummary(
        open: _asIntOrNull(json['open']) ?? 0,
        blockers: _asIntOrNull(json['blockers']) ?? 0,
        byType: (json['by_type'] as List?)
                ?.whereType<Map>()
                .map((m) => ExceptionTypeCount.fromJson(m.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [open, blockers, byType];
}

class ExceptionTypeCount extends Equatable {
  const ExceptionTypeCount({
    required this.exceptionType,
    required this.name,
    required this.severity,
    required this.open,
    this.category = 'OTHER',
  });

  final String exceptionType;
  final String name;
  final String category;
  final ExceptionSeverity severity;
  final int open;

  factory ExceptionTypeCount.fromJson(Map<String, dynamic> json) =>
      ExceptionTypeCount(
        exceptionType: (json['exception_type'] ?? '').toString(),
        name: _asText(json['name']) ?? (json['exception_type'] ?? '').toString(),
        category: (json['category'] ?? 'OTHER').toString(),
        severity: ExceptionSeverity.fromCode(json['severity']),
        open: _asIntOrNull(json['open']) ?? 0,
      );

  @override
  List<Object?> get props => [exceptionType, severity, open];
}
