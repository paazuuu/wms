import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// A warehouse abroad whose stock this system does not hold (0088): goods
/// sent there leave real stock, and a rough virtual figure is kept instead.
class VirtualWarehouse extends Equatable {
  const VirtualWarehouse({required this.id, required this.name, this.code = '', this.countryCode = ''});

  final int id;
  final String code;
  final String name;
  final String countryCode;

  factory VirtualWarehouse.fromJson(Map<String, dynamic> json) => VirtualWarehouse(
        id: _asInt(json['id']),
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        countryCode: (json['country_code'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [id, code, name, countryCode];
}

/// Opening, what arrived from Japan, what was typed in, what the counts
/// corrected, and closing — for a whole range, one month, or one product.
class VirtualFigures extends Equatable {
  const VirtualFigures({
    this.opening = 0,
    this.arrived = 0,
    this.adjusted = 0,
    this.countDiff = 0,
    this.closing = 0,
  });

  final int opening;

  /// Sent from Japan (exports), counted in automatically.
  final int arrived;

  /// Known changes typed in by hand.
  final int adjusted;

  /// What counts corrected: closing minus everything recorded. Negative is
  /// mostly what left the warehouse without anyone telling the system.
  final int countDiff;
  final int closing;

  factory VirtualFigures.fromJson(Map<String, dynamic> json) => VirtualFigures(
        opening: _asInt(json['opening']),
        arrived: _asInt(json['arrived']),
        adjusted: _asInt(json['adjusted']),
        countDiff: _asInt(json['count_diff']),
        closing: _asInt(json['closing']),
      );

  @override
  List<Object?> get props => [opening, arrived, adjusted, countDiff, closing];
}

class VirtualMonth extends Equatable {
  const VirtualMonth({required this.month, required this.figures});

  /// YYYY-MM.
  final String month;
  final VirtualFigures figures;

  factory VirtualMonth.fromJson(Map<String, dynamic> json) => VirtualMonth(
        month: (json['month'] ?? '').toString(),
        figures: VirtualFigures.fromJson(json),
      );

  @override
  List<Object?> get props => [month, figures];
}

class VirtualProduct extends Equatable {
  const VirtualProduct({
    required this.productId,
    required this.janCode,
    required this.productName,
    required this.figures,
    this.lastCountOn,
    this.lastCounted,
  });

  final int productId;
  final String janCode;
  final String productName;
  final VirtualFigures figures;
  final DateTime? lastCountOn;
  final int? lastCounted;

  factory VirtualProduct.fromJson(Map<String, dynamic> json) {
    final last = json['last_count'];
    return VirtualProduct(
      productId: _asInt(json['product_id']),
      janCode: (json['jan_code'] ?? '').toString(),
      productName: (json['product_name'] ?? '').toString(),
      figures: VirtualFigures.fromJson(json),
      lastCountOn: last is Map ? DateTime.tryParse('${last['occurred_on']}') : null,
      lastCounted: last is Map ? _asInt(last['counted']) : null,
    );
  }

  @override
  List<Object?> get props => [productId, janCode, figures, lastCountOn, lastCounted];
}

class VirtualStockSummary extends Equatable {
  const VirtualStockSummary({
    required this.totals,
    this.months = const [],
    this.products = const [],
  });

  final VirtualFigures totals;
  final List<VirtualMonth> months;
  final List<VirtualProduct> products;

  static List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
      (v as List?)?.whereType<Map>().map((e) => f(e.cast<String, dynamic>())).toList() ??
      <T>[];

  factory VirtualStockSummary.fromJson(Map<String, dynamic> json) => VirtualStockSummary(
        totals: VirtualFigures.fromJson(
            (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {}),
        months: _list(json['months'], VirtualMonth.fromJson),
        products: _list(json['products'], VirtualProduct.fromJson),
      );

  @override
  List<Object?> get props => [totals, months, products];
}

/// One entry of the virtual ledger.
enum VirtualEntryType {
  exportIn('EXPORT_IN'),
  count('COUNT'),
  adjust('ADJUST');

  const VirtualEntryType(this.wire);
  final String wire;

  static VirtualEntryType parse(String? v) => switch (v) {
        'COUNT' => VirtualEntryType.count,
        'ADJUST' => VirtualEntryType.adjust,
        _ => VirtualEntryType.exportIn,
      };
}

class VirtualStockEntry extends Equatable {
  const VirtualStockEntry({
    required this.id,
    required this.type,
    required this.occurredOn,
    this.quantity = 0,
    this.countedQuantity,
    this.note,
    this.transferNumber,
    this.balanceThatDay = 0,
  });

  final int id;
  final VirtualEntryType type;
  final DateTime occurredOn;
  final int quantity;
  final int? countedQuantity;
  final String? note;
  final String? transferNumber;
  final int balanceThatDay;

  /// Only what was typed in can be taken back; an arrival follows its transfer.
  bool get isManual => type != VirtualEntryType.exportIn;

  factory VirtualStockEntry.fromJson(Map<String, dynamic> json) => VirtualStockEntry(
        id: _asInt(json['id']),
        type: VirtualEntryType.parse(json['entry_type'] as String?),
        occurredOn: DateTime.tryParse('${json['occurred_on']}') ?? DateTime(1970),
        quantity: _asInt(json['quantity']),
        countedQuantity:
            json['counted_quantity'] == null ? null : _asInt(json['counted_quantity']),
        note: json['note'] as String?,
        transferNumber: json['transfer_number'] as String?,
        balanceThatDay: _asInt(json['balance_that_day']),
      );

  @override
  List<Object?> get props => [id, type, occurredOn, quantity, countedQuantity, note];
}
