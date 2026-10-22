import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../domain/stock_history.dart';

/// How stock came to be (0145): for one product, and for the library.
abstract class StockHistoryRepository {
  Future<ApiResult<ProductStockHistory>> product(int productId, {int? warehouseId, int days = 90});

  Future<ApiResult<LibraryInflow>> library({int? warehouseId, int days = 90});
}

class StockHistoryRepositoryImpl implements StockHistoryRepository {
  StockHistoryRepositoryImpl(this._rest);

  final Dio _rest;

  Future<ApiResult<T>> _rpc<T>(String name, Map<String, dynamic> body, T Function(Map<String, dynamic>) read) async {
    try {
      final r = await _rest.post('/rpc/$name', data: body);
      final d = r.data is List && (r.data as List).isNotEmpty ? (r.data as List).first : r.data;
      return ApiSuccess(read((d as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  @override
  Future<ApiResult<ProductStockHistory>> product(int productId, {int? warehouseId, int days = 90}) => _rpc(
      'product_stock_history',
      {'p_product_id': productId, 'p_warehouse_id': warehouseId, 'p_days': days},
      ProductStockHistory.fromJson);

  @override
  Future<ApiResult<LibraryInflow>> library({int? warehouseId, int days = 90}) =>
      _rpc('library_stock_inflow', {'p_warehouse_id': warehouseId, 'p_days': days}, LibraryInflow.fromJson);
}

final stockHistoryRepositoryProvider =
    Provider<StockHistoryRepository>((ref) => StockHistoryRepositoryImpl(ref.watch(restDioProvider)));

/// The period both charts show, in days.
final stockHistoryDaysProvider = StateProvider<int>((_) => 90);

final productStockHistoryProvider =
    FutureProvider.autoDispose.family<ProductStockHistory, (int, int?)>((ref, key) async {
  final days = ref.watch(stockHistoryDaysProvider);
  final r = await ref.watch(stockHistoryRepositoryProvider).product(key.$1, warehouseId: key.$2, days: days);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

final libraryInflowProvider = FutureProvider.autoDispose.family<LibraryInflow, int?>((ref, warehouseId) async {
  final days = ref.watch(stockHistoryDaysProvider);
  final r = await ref.watch(stockHistoryRepositoryProvider).library(warehouseId: warehouseId, days: days);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
