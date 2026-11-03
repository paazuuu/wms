import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';

int? _ni(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
double? _nd(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
String? _s(Object? v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

DateTime? _day(Object? v) {
  final d = DateTime.tryParse('${v ?? ''}');
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

String _wire(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Where a price came from (0187/0188).
enum PriceSource {
  /// A stock file (発注 / 予定外の入荷).
  receipt,

  /// Written by hand on the product.
  manual,

  /// A 出荷リスト's row: shown on its own, kept out of the averages.
  outbound;

  static PriceSource fromWire(String? v) =>
      PriceSource.values.firstWhere((e) => e.name == v, orElse: () => PriceSource.receipt);
}

/// One time the product was bought (or shipped at a price).
class PricePoint extends Equatable {
  const PricePoint({
    required this.id,
    required this.source,
    required this.day,
    required this.unitPrice,
    this.supplierId,
    this.supplierName = '',
    this.taxRate = 10,
    this.unitPriceTax,
    this.quantity,
    this.importId,
    this.fileId,
    this.lineNo,
    this.fileName,
    this.note,
    this.entryId,
  });

  final String id;
  final PriceSource source;
  final DateTime day;
  final int? supplierId;
  final String supplierName;

  /// 税抜.
  final double unitPrice;
  final double taxRate;
  final double? unitPriceTax;
  final int? quantity;
  final int? importId;
  final int? fileId;
  final int? lineNo;
  final String? fileName;
  final String? note;

  /// A hand-written one: can be withdrawn.
  final int? entryId;

  /// The supplier as grouped: by id, else by name.
  String get supplierKey => supplierId != null ? 'id:$supplierId' : 'name:$supplierName';

  factory PricePoint.fromJson(Map<String, dynamic> j) => PricePoint(
        id: '${j['id'] ?? ''}',
        source: PriceSource.fromWire(_s(j['source'])),
        day: _day(j['day']) ?? DateTime(2000),
        supplierId: _ni(j['supplier_id']),
        supplierName: _s(j['supplier_name']) ?? '',
        unitPrice: _nd(j['unit_price']) ?? 0,
        taxRate: _nd(j['tax_rate']) ?? 10,
        unitPriceTax: _nd(j['unit_price_tax']),
        quantity: _ni(j['quantity']),
        importId: _ni(j['import_id']),
        fileId: _ni(j['file_id']),
        lineNo: _ni(j['line_no']),
        fileName: _s(j['file_name']),
        note: _s(j['note']),
        entryId: _ni(j['entry_id']),
      );

  @override
  List<Object?> get props => [id, source, day, supplierId, supplierName, unitPrice, quantity];
}

/// A month's price over every supplier, weighted by quantity.
class PriceMonth extends Equatable {
  const PriceMonth({required this.month, required this.average, this.min, this.max, this.quantity = 0, this.count = 0});

  /// The month's first day.
  final DateTime month;
  final double average;
  final double? min;
  final double? max;
  final int quantity;
  final int count;

  factory PriceMonth.fromJson(Map<String, dynamic> j) {
    final m = '${j['month'] ?? ''}'.split('-');
    return PriceMonth(
      month: DateTime(int.tryParse(m.first) ?? 2000, m.length > 1 ? int.tryParse(m[1]) ?? 1 : 1),
      average: _nd(j['average']) ?? 0,
      min: _nd(j['min']),
      max: _nd(j['max']),
      quantity: _ni(j['quantity']) ?? 0,
      count: _ni(j['count']) ?? 0,
    );
  }

  @override
  List<Object?> get props => [month, average, quantity, count];
}

/// One supplier's prices: the last, the average, how often.
class SupplierPrice extends Equatable {
  const SupplierPrice({
    required this.supplierName,
    this.supplierId,
    this.count = 0,
    this.quantity = 0,
    this.average,
    this.lastPrice,
    this.lastDay,
    this.min,
    this.max,
  });

  final int? supplierId;
  final String supplierName;
  final int count;
  final int quantity;
  final double? average;
  final double? lastPrice;
  final DateTime? lastDay;
  final double? min;
  final double? max;

  String get supplierKey => supplierId != null ? 'id:$supplierId' : 'name:$supplierName';

  factory SupplierPrice.fromJson(Map<String, dynamic> j) => SupplierPrice(
        supplierId: _ni(j['supplier_id']),
        supplierName: _s(j['supplier_name']) ?? '',
        count: _ni(j['count']) ?? 0,
        quantity: _ni(j['quantity']) ?? 0,
        average: _nd(j['average']),
        lastPrice: _nd(j['last_price']),
        lastDay: _day(j['last_day']),
        min: _nd(j['min']),
        max: _nd(j['max']),
      );

  @override
  List<Object?> get props => [supplierId, supplierName, count, average, lastPrice, lastDay];
}

class PurchasePrices extends Equatable {
  const PurchasePrices({this.points = const [], this.monthly = const [], this.suppliers = const []});

  final List<PricePoint> points;
  final List<PriceMonth> monthly;
  final List<SupplierPrice> suppliers;

  bool get isEmpty => points.isEmpty;

  factory PurchasePrices.fromJson(Map<String, dynamic> j) => PurchasePrices(
        points: [for (final e in (j['points'] as List? ?? const []).whereType<Map>()) PricePoint.fromJson(e.cast<String, dynamic>())],
        monthly: [for (final e in (j['monthly'] as List? ?? const []).whereType<Map>()) PriceMonth.fromJson(e.cast<String, dynamic>())],
        suppliers: [
          for (final e in (j['suppliers'] as List? ?? const []).whereType<Map>()) SupplierPrice.fromJson(e.cast<String, dynamic>()),
        ],
      );

  @override
  List<Object?> get props => [points, monthly, suppliers];
}

/// 仕入れ値の履歴 (0187).
abstract class PurchasePriceRepository {
  Future<ApiResult<PurchasePrices>> forProduct(int productId);

  Future<ApiResult<int>> record({
    required int productId,
    required double unitPrice,
    required DateTime pricedOn,
    int? supplierId,
    String? supplierName,
    double taxRate = 10,
    int? quantity,
    String? note,
  });

  Future<ApiResult<bool>> withdraw(int entryId);
}

class PurchasePriceRepositoryImpl implements PurchasePriceRepository {
  PurchasePriceRepositoryImpl(this._rest);

  final Dio _rest;

  @override
  Future<ApiResult<PurchasePrices>> forProduct(int productId) async {
    try {
      final r = await _rest.post('/rpc/product_purchase_prices', data: {'p_product_id': productId});
      return ApiSuccess(PurchasePrices.fromJson((r.data as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<PurchasePrices>(e);
    }
  }

  @override
  Future<ApiResult<int>> record({
    required int productId,
    required double unitPrice,
    required DateTime pricedOn,
    int? supplierId,
    String? supplierName,
    double taxRate = 10,
    int? quantity,
    String? note,
  }) async {
    try {
      final r = await _rest.post('/rpc/purchase_price_record', data: {
        'p_product_id': productId,
        'p_unit_price': unitPrice,
        'p_priced_on': _wire(pricedOn),
        'p_supplier_id': supplierId,
        'p_supplier_name': supplierName,
        'p_tax_rate': taxRate,
        'p_quantity': quantity,
        'p_note': note,
      });
      return ApiSuccess(_ni(r.data) ?? 0);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<bool>> withdraw(int entryId) async {
    try {
      await _rest.post('/rpc/purchase_price_withdraw', data: {'p_id': entryId});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}

final purchasePriceRepositoryProvider =
    Provider<PurchasePriceRepository>((ref) => PurchasePriceRepositoryImpl(ref.watch(restDioProvider)));

final purchasePricesProvider = FutureProvider.autoDispose.family<PurchasePrices, int>((ref, productId) async {
  final r = await ref.watch(purchasePriceRepositoryProvider).forProduct(productId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
