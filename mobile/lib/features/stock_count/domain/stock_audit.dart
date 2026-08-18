import 'package:equatable/equatable.dart';

import 'stock_audit_item.dart';

/// Lifecycle of a stock count (cycle count / audit).
enum StockAuditStatus { draft, inProgress, completed, cancelled }

StockAuditStatus parseStockAuditStatus(String? value) => switch (value) {
      'in_progress' => StockAuditStatus.inProgress,
      'completed' => StockAuditStatus.completed,
      'cancelled' => StockAuditStatus.cancelled,
      _ => StockAuditStatus.draft,
    };

/// A stock count / audit as returned by the backend `StockAuditResource`.
class StockAudit extends Equatable {
  const StockAudit({
    required this.id,
    required this.auditNumber,
    required this.status,
    this.name,
    this.auditType,
    this.locationName,
    this.startedAt,
    this.completedAt,
    this.notes,
    this.itemsCount,
    this.items = const [],
  });

  final int id;
  final String auditNumber;
  final StockAuditStatus status;
  final String? name;
  final String? auditType;
  final String? locationName;
  final String? startedAt;
  final String? completedAt;
  final String? notes;
  final int? itemsCount;
  final List<StockAuditItem> items;

  factory StockAudit.fromJson(Map<String, dynamic> json) {
    final location = json['warehouse_location'];
    final rawItems = json['items'];
    return StockAudit(
      id: json['id'] as int,
      auditNumber: json['audit_number'] as String? ?? '#${json['id']}',
      status: parseStockAuditStatus(json['status'] as String?),
      name: json['name'] as String?,
      auditType: json['audit_type'] as String?,
      locationName: location is Map<String, dynamic>
          ? location['name'] as String?
          : null,
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
      notes: json['notes'] as String?,
      itemsCount: _asInt(json['items_count']),
      items: rawItems is List
          ? rawItems
              .map((e) => StockAuditItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  @override
  List<Object?> get props => [id, auditNumber, status, itemsCount];
}
