import 'package:equatable/equatable.dart';

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
  });

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
      );

  @override
  List<Object?> get props => [id, code, name, countryCode, receivesCrossBorder];
}
