import 'package:equatable/equatable.dart';

/// The executed output of a saved report: the ordered columns with their human
/// labels, and the resulting rows keyed by column.
class ReportResult extends Equatable {
  const ReportResult({
    required this.id,
    required this.name,
    this.description,
    this.columns = const [],
    this.columnLabels = const {},
    this.rows = const [],
    this.total = 0,
  });

  final int id;
  final String name;
  final String? description;
  final List<String> columns;
  final Map<String, String> columnLabels;
  final List<Map<String, dynamic>> rows;
  final int total;

  /// The display label for a column key, falling back to the raw key.
  String labelFor(String column) => columnLabels[column] ?? column;

  /// A single cell value as display text.
  String cell(Map<String, dynamic> row, String column) {
    final value = row[column];
    if (value == null) return '—';
    return '$value';
  }

  factory ReportResult.fromJson(Map<String, dynamic> json) {
    final report = json['report'];
    final reportMap = report is Map<String, dynamic> ? report : const {};
    final rawColumns = reportMap['columns'];
    final rawLabels = json['column_labels'];
    final rawRows = json['rows'];
    return ReportResult(
      id: _asInt(reportMap['id']) ?? 0,
      name: reportMap['name'] as String? ?? 'Report',
      description: reportMap['description'] as String?,
      columns: rawColumns is List
          ? rawColumns.map((e) => '$e').toList()
          : const [],
      columnLabels: rawLabels is Map
          ? rawLabels.map((k, v) => MapEntry('$k', '$v'))
          : const {},
      rows: rawRows is List
          ? rawRows
              .whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry('$k', v)))
              .toList()
          : const [],
      total: _asInt(json['total']) ?? 0,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  @override
  List<Object?> get props => [id, name, columns, total];
}
