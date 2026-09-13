import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// A fixed, server-defined data source `run_report` (0037) can query —
/// never arbitrary user SQL. Each has its own small filter set.
enum ReportSource {
  stockMovements('stock_movements'),
  purchaseOrders('purchase_orders'),
  salesOrders('sales_orders'),
  workOrders('work_orders'),
  auditLog('audit_log'),
  products('products');

  const ReportSource(this.wire);
  final String wire;

  static ReportSource parse(String? value) => switch (value) {
        'purchase_orders' => ReportSource.purchaseOrders,
        'sales_orders' => ReportSource.salesOrders,
        'work_orders' => ReportSource.workOrders,
        'audit_log' => ReportSource.auditLog,
        'products' => ReportSource.products,
        _ => ReportSource.stockMovements,
      };
}

/// The result of running one report: the source it ran against and the
/// matching rows, each a loosely-typed map rendered generically (the set of
/// columns differs per source).
class ReportResult extends Equatable {
  const ReportResult({required this.source, required this.rows});

  final ReportSource source;
  final List<Map<String, dynamic>> rows;

  factory ReportResult.fromJson(Map<String, dynamic> json) => ReportResult(
        source: ReportSource.parse(json['source'] as String?),
        rows: (json['rows'] as List?)
                ?.whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [source, rows];
}

/// One saved source+filters combination (spec §46 checklist item 10, 0037)
/// — the "custom/saved" part of the report builder, so a frequently-run
/// query doesn't need re-entering its filters each time.
class ReportDefinition extends Equatable {
  const ReportDefinition({
    required this.id,
    required this.name,
    required this.source,
    this.filters = const {},
    this.createdAt,
  });

  final int id;
  final String name;
  final ReportSource source;
  final Map<String, dynamic> filters;
  final DateTime? createdAt;

  factory ReportDefinition.fromJson(Map<String, dynamic> json) => ReportDefinition(
        id: _asInt(json['id']),
        name: (json['name'] ?? '').toString(),
        source: ReportSource.parse(json['source'] as String?),
        filters: (json['filters'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props => [id, name, source, filters];
}
