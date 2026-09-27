import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// A warehouse as a chart series. A warehouse abroad appears twice when it
/// has both: its real stock, and its virtual figure (0088).
class ChartWarehouse extends Equatable {
  const ChartWarehouse({
    required this.id,
    required this.name,
    this.countryCode = '',
    this.isVirtual = false,
  });

  final int id;
  final String name;
  final String countryCode;
  final bool isVirtual;

  String get key => '$id${isVirtual ? 'v' : ''}';

  factory ChartWarehouse.fromJson(Map<String, dynamic> json) => ChartWarehouse(
        id: _asInt(json['id']),
        name: (json['name'] ?? '').toString(),
        countryCode: (json['country_code'] ?? '').toString(),
        isVirtual: json['virtual'] == true,
      );

  @override
  List<Object?> get props => [id, name, countryCode, isVirtual];
}

class ChartProduct extends Equatable {
  const ChartProduct({
    required this.productId,
    required this.janCode,
    required this.productName,
    required this.total,
    this.free = 0,
    this.reserved = 0,
    this.unusable = 0,
    this.virtualAbroad = 0,
    this.byWarehouse = const {},
  });

  final int productId;
  final String janCode;
  final String productName;

  /// Real on-hand plus the virtual figure abroad.
  final int total;
  final int free;
  final int reserved;
  final int unusable;
  final int virtualAbroad;

  /// Quantity per [ChartWarehouse.key].
  final Map<String, int> byWarehouse;

  String get displayName => productName.isNotEmpty ? productName : janCode;

  factory ChartProduct.fromJson(Map<String, dynamic> json) => ChartProduct(
        productId: _asInt(json['product_id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productName: (json['product_name'] ?? '').toString(),
        total: _asInt(json['total']),
        free: _asInt(json['free']),
        reserved: _asInt(json['reserved']),
        unusable: _asInt(json['unusable']),
        virtualAbroad: _asInt(json['virtual_abroad']),
        byWarehouse: {
          for (final e in (json['by_warehouse'] as List? ?? const []).whereType<Map>())
            '${_asInt(e['warehouse_id'])}${e['virtual'] == true ? 'v' : ''}': _asInt(e['quantity']),
        },
      );

  @override
  List<Object?> get props =>
      [productId, total, free, reserved, unusable, virtualAbroad, byWarehouse];
}

/// `dashboard_stock_chart` (0089): the top products by stock, with both
/// breakdowns a stacked bar can show.
class StockChartData extends Equatable {
  const StockChartData({
    this.warehouses = const [],
    this.products = const [],
    this.productCount = 0,
    this.countryCode = '',
    this.countries = const [],
    this.unregisteredJans = 0,
    this.unregisteredUnits = 0,
  });

  /// Stock under JANs with no product record yet: not in any bar (0094), so
  /// the dashboard says how much is left out and where to register it.
  final int unregisteredJans;
  final int unregisteredUnits;

  /// The one country charted — never a sum across a border (0090).
  final String countryCode;

  /// Countries with anything to chart, home first.
  final List<String> countries;

  final List<ChartWarehouse> warehouses;
  final List<ChartProduct> products;

  /// How many products hold stock at all, of which [products] are the top.
  final int productCount;

  factory StockChartData.fromJson(Map<String, dynamic> json) => StockChartData(
        warehouses: [
          for (final e in (json['warehouses'] as List? ?? const []).whereType<Map>())
            ChartWarehouse.fromJson(e.cast<String, dynamic>()),
        ],
        products: [
          for (final e in (json['products'] as List? ?? const []).whereType<Map>())
            ChartProduct.fromJson(e.cast<String, dynamic>()),
        ],
        productCount: _asInt(json['product_count']),
        countryCode: (json['country_code'] ?? '').toString(),
        countries: [for (final c in (json['countries'] as List? ?? const [])) '$c'],
        unregisteredJans: _asInt((json['unregistered'] as Map?)?['jan_count']),
        unregisteredUnits: _asInt((json['unregistered'] as Map?)?['units']),
      );

  @override
  List<Object?> get props => [
        warehouses, products, productCount, countryCode, countries,
        unregisteredJans, unregisteredUnits,
      ];
}

/// One of the latest purchase orders, with where it is bound for.
class RecentPurchaseOrder extends Equatable {
  const RecentPurchaseOrder({
    required this.id,
    required this.status,
    this.poNumber,
    this.supplierName = '',
    this.warehouseId,
    this.warehouseName = '',
    this.countryCode = '',
    this.expectedDate,
    this.createdAt,
    this.lineCount = 0,
    this.orderedUnits = 0,
    this.receivedUnits = 0,
  });

  final int id;
  final String status;
  final String? poNumber;
  final String supplierName;
  final int? warehouseId;
  final String warehouseName;
  final String countryCode;
  final DateTime? expectedDate;
  final DateTime? createdAt;
  final int lineCount;
  final int orderedUnits;
  final int receivedUnits;

  double get receivedRatio =>
      orderedUnits <= 0 ? 0 : (receivedUnits / orderedUnits).clamp(0, 1).toDouble();

  factory RecentPurchaseOrder.fromJson(Map<String, dynamic> json) => RecentPurchaseOrder(
        id: _asInt(json['id']),
        status: (json['status'] ?? '').toString(),
        poNumber: json['po_number'] as String?,
        supplierName: (json['supplier_name'] ?? '').toString(),
        warehouseId: json['warehouse_id'] == null ? null : _asInt(json['warehouse_id']),
        warehouseName: (json['warehouse_name'] ?? '').toString(),
        countryCode: (json['country_code'] ?? '').toString(),
        expectedDate: json['expected_date'] == null
            ? null
            : DateTime.tryParse('${json['expected_date']}'),
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        lineCount: _asInt(json['line_count']),
        orderedUnits: _asInt(json['ordered_units']),
        receivedUnits: _asInt(json['received_units']),
      );

  @override
  List<Object?> get props =>
      [id, status, poNumber, supplierName, warehouseId, orderedUnits, receivedUnits];
}
