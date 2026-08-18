import 'package:equatable/equatable.dart';

/// Summary of a saved report as returned by the `/reports` list endpoint.
class SavedReport extends Equatable {
  const SavedReport({
    required this.id,
    required this.name,
    this.description,
    this.dataSource,
    this.isShared = false,
    this.isOwner = false,
    this.creatorName,
    this.columnsCount = 0,
    this.filtersCount = 0,
    this.chartType,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? description;
  final String? dataSource;
  final bool isShared;
  final bool isOwner;
  final String? creatorName;
  final int columnsCount;
  final int filtersCount;
  final String? chartType;
  final String? updatedAt;

  factory SavedReport.fromJson(Map<String, dynamic> json) {
    return SavedReport(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Untitled report',
      description: json['description'] as String?,
      dataSource: json['data_source'] as String?,
      isShared: json['is_shared'] as bool? ?? false,
      isOwner: json['is_owner'] as bool? ?? false,
      creatorName: json['creator_name'] as String?,
      columnsCount: _asInt(json['columns_count']) ?? 0,
      filtersCount: _asInt(json['filters_count']) ?? 0,
      chartType: json['chart_type'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  @override
  List<Object?> get props => [id, name, dataSource, isShared, columnsCount];
}
