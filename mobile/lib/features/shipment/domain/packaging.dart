import 'package:equatable/equatable.dart';

double? _d(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
int _i(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String? _s(dynamic v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) parse) => raw is List
    ? raw.whereType<Map>().map((e) => parse(e.cast<String, dynamic>())).toList(growable: false)
    : const [];

/// A box we ship in (0115): its size, what it weighs empty, the packing
/// material that usually goes in with it, and how much it takes.
class CartonType extends Equatable {
  const CartonType({
    this.id,
    required this.name,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.emptyWeightG = 0,
    this.packingMaterialG = 0,
    this.maxLoadKg,
    this.isDefault = false,
    this.active = true,
  });

  final int? id;
  final String name;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final double emptyWeightG;
  final double packingMaterialG;
  final double? maxLoadKg;
  final bool isDefault;
  final bool active;

  factory CartonType.fromJson(Map<String, dynamic> j) => CartonType(
        id: _i(j['id']),
        name: (j['name'] ?? '').toString(),
        lengthCm: _d(j['length_cm']),
        widthCm: _d(j['width_cm']),
        heightCm: _d(j['height_cm']),
        emptyWeightG: _d(j['empty_weight_g']) ?? 0,
        packingMaterialG: _d(j['packing_material_g']) ?? 0,
        maxLoadKg: _d(j['max_load_kg']),
        isDefault: j['is_default'] == true,
        active: j['status'] != 'inactive',
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'length_cm': lengthCm,
        'width_cm': widthCm,
        'height_cm': heightCm,
        'empty_weight_g': emptyWeightG,
        'packing_material_g': packingMaterialG,
        'max_load_kg': maxLoadKg,
        'is_default': isDefault,
        'status': active ? 'active' : 'inactive',
      };

  /// "40×30×30 cm", or null when the size is not known.
  String? get sizeText {
    final parts = [lengthCm, widthCm, heightCm];
    if (parts.any((p) => p == null)) return null;
    String n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
    return '${parts.map((p) => n(p!)).join('×')} cm';
  }

  @override
  List<Object?> get props =>
      [id, name, lengthCm, widthCm, heightCm, emptyWeightG, packingMaterialG, maxLoadKg, isDefault, active];
}

/// One product line of a shipment with its weight, or none yet.
class WeightLine extends Equatable {
  const WeightLine({
    this.productId,
    required this.janCode,
    required this.productName,
    required this.quantity,
    this.unitWeightG,
    this.lineWeightG,
  });

  final int? productId;
  final String janCode;
  final String productName;
  final int quantity;
  final double? unitWeightG;
  final double? lineWeightG;

  bool get missing => unitWeightG == null;

  factory WeightLine.fromJson(Map<String, dynamic> j) => WeightLine(
        productId: j['product_id'] == null ? null : _i(j['product_id']),
        janCode: (j['jan_code'] ?? '').toString(),
        productName: (j['product_name'] ?? '').toString(),
        quantity: _i(j['quantity']),
        unitWeightG: _d(j['unit_weight_g']),
        lineWeightG: _d(j['line_weight_g']),
      );

  @override
  List<Object?> get props => [productId, janCode, productName, quantity, unitWeightG, lineWeightG];
}

/// A real carton of the shipment, with its packaging and contents weight.
class EstimateCarton extends Equatable {
  const EstimateCarton({
    required this.cartonId,
    required this.cartonNo,
    this.cartonTypeId,
    this.cartonType,
    this.emptyWeightG,
    this.packingMaterialG,
    this.contentsWeightG,
    this.measuredWeightKg,
  });

  final int cartonId;
  final int cartonNo;
  final int? cartonTypeId;
  final String? cartonType;
  final double? emptyWeightG;
  final double? packingMaterialG;
  final double? contentsWeightG;
  final double? measuredWeightKg;

  /// What the box should weigh: contents, the box itself and its packing.
  double get estimatedG => (contentsWeightG ?? 0) + (emptyWeightG ?? 0) + (packingMaterialG ?? 0);

  factory EstimateCarton.fromJson(Map<String, dynamic> j) => EstimateCarton(
        cartonId: _i(j['carton_id']),
        cartonNo: _i(j['carton_no']),
        cartonTypeId: j['carton_type_id'] == null ? null : _i(j['carton_type_id']),
        cartonType: _s(j['carton_type']),
        emptyWeightG: _d(j['empty_weight_g']),
        packingMaterialG: _d(j['packing_material_g']),
        contentsWeightG: _d(j['contents_weight_g']),
        measuredWeightKg: _d(j['measured_weight_kg']),
      );

  @override
  List<Object?> get props =>
      [cartonId, cartonNo, cartonTypeId, cartonType, emptyWeightG, packingMaterialG, contentsWeightG, measuredWeightKg];
}

/// How many of one box a shipment is expected to need, before packing.
class PlannedCarton extends Equatable {
  const PlannedCarton({
    required this.cartonTypeId,
    this.cartonType = '',
    required this.quantity,
    this.emptyWeightG,
    this.packingMaterialG,
  });

  final int cartonTypeId;
  final String cartonType;
  final int quantity;
  final double? emptyWeightG;
  final double? packingMaterialG;

  factory PlannedCarton.fromJson(Map<String, dynamic> j) => PlannedCarton(
        cartonTypeId: _i(j['carton_type_id']),
        cartonType: (j['carton_type'] ?? '').toString(),
        quantity: _i(j['quantity']),
        emptyWeightG: _d(j['empty_weight_g']),
        packingMaterialG: _d(j['packing_material_g']),
      );

  Map<String, dynamic> toJson() => {
        'carton_type_id': cartonTypeId,
        'quantity': quantity,
        if (emptyWeightG != null) 'empty_weight_g': emptyWeightG,
        if (packingMaterialG != null) 'packing_material_g': packingMaterialG,
      };

  @override
  List<Object?> get props => [cartonTypeId, cartonType, quantity, emptyWeightG, packingMaterialG];
}

/// `shipment_weight_estimate` (0115): what a shipment should weigh — goods,
/// boxes and packing material — from its real cartons once there are any,
/// else from the planned ones.
class ShipmentWeightEstimate extends Equatable {
  const ShipmentWeightEstimate({
    this.lines = const [],
    this.goodsWeightG = 0,
    this.missingWeights = 0,
    this.fromCartons = false,
    this.cartons = const [],
    this.planned = const [],
    this.cartonCount = 0,
    this.boxesWeightG = 0,
    this.packingMaterialG = 0,
    this.totalWeightG = 0,
    this.measuredWeightG,
    this.suggested = const [],
  });

  final List<WeightLine> lines;
  final double goodsWeightG;
  final int missingWeights;

  /// True once the shipment has real cartons; the boxes then come from them.
  final bool fromCartons;
  final List<EstimateCarton> cartons;
  final List<PlannedCarton> planned;
  final int cartonCount;
  final double boxesWeightG;
  final double packingMaterialG;
  final double totalWeightG;

  /// The cartons as weighed (their measured weights added up), when any were.
  final double? measuredWeightG;

  /// How many of each box the goods would need by weight alone.
  final List<PlannedCarton> suggested;

  factory ShipmentWeightEstimate.fromJson(Map<String, dynamic> j) => ShipmentWeightEstimate(
        lines: _list(j['lines'], WeightLine.fromJson),
        goodsWeightG: _d(j['goods_weight_g']) ?? 0,
        missingWeights: _i(j['missing_weights']),
        fromCartons: j['cartons_from'] == 'cartons',
        cartons: _list(j['cartons'], EstimateCarton.fromJson),
        planned: _list(j['planned'], PlannedCarton.fromJson),
        cartonCount: _i(j['carton_count']),
        boxesWeightG: _d(j['boxes_weight_g']) ?? 0,
        packingMaterialG: _d(j['packing_material_g']) ?? 0,
        totalWeightG: _d(j['total_weight_g']) ?? 0,
        measuredWeightG: _d(j['measured_weight_g']),
        suggested: _list(j['suggested'], PlannedCarton.fromJson),
      );

  @override
  List<Object?> get props => [
        lines, goodsWeightG, missingWeights, fromCartons, cartons, planned, cartonCount,
        boxesWeightG, packingMaterialG, totalWeightG, measuredWeightG, suggested,
      ];
}
