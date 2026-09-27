import 'package:equatable/equatable.dart';

import '../../qc/domain/inspection.dart' show WarehouseInspectionMode;

export '../../qc/domain/inspection.dart' show WarehouseInspectionMode;

/// Which country a warehouse is in, and whether it holds stock that arrives
/// across a border (0087). Without that switch, a transfer to it from another
/// country leaves this system at the source.
class WarehouseRole extends Equatable {
  const WarehouseRole({
    required this.id,
    required this.name,
    this.code = '',
    this.countryCode = 'JP',
    this.receivesCrossBorder = false,
    this.inspectionMode = WarehouseInspectionMode.full,
    this.samplePercent = 10,
    this.sampleMin = 1,
  });

  /// How goods from suppliers are inspected here (0104): all of them (the
  /// default, and what a new warehouse gets), on a sample, or not in this
  /// system at all — receive only, when the warehouse inspects its own way.
  final WarehouseInspectionMode inspectionMode;
  final int samplePercent;
  final int sampleMin;

  final int id;
  final String code;
  final String name;
  final String countryCode;
  final bool receivesCrossBorder;

  /// Whether sending from [source] to this warehouse takes the goods out of
  /// the system.
  bool exportsFrom(WarehouseRole source) =>
      source.countryCode != countryCode && !receivesCrossBorder;

  factory WarehouseRole.fromJson(Map<String, dynamic> json) => WarehouseRole(
        id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        countryCode: (json['country_code'] ?? 'JP').toString(),
        receivesCrossBorder: json['receives_cross_border'] == true,
        inspectionMode: WarehouseInspectionMode.parse(json['inspection_mode'] as String?),
        samplePercent: json['sample_percent'] is num
            ? (json['sample_percent'] as num).toInt()
            : int.tryParse('${json['sample_percent']}') ?? 10,
        sampleMin: json['sample_min'] is num
            ? (json['sample_min'] as num).toInt()
            : int.tryParse('${json['sample_min']}') ?? 1,
      );

  @override
  List<Object?> get props =>
      [id, code, name, countryCode, receivesCrossBorder, inspectionMode, samplePercent, sampleMin];
}
