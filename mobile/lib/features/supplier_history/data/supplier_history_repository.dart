import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../domain/supplier_history.dart';

/// 仕入先から (0143).
abstract class SupplierHistoryRepository {
  Future<ApiResult<List<SupplierCard>>> cards({String? search});

  /// One supplier, with stock counted in [warehouseId] (every warehouse
  /// allowed when null).
  Future<ApiResult<SupplierHistory>> history(int supplierId, {int? warehouseId});
}

class SupplierHistoryRepositoryImpl implements SupplierHistoryRepository {
  SupplierHistoryRepositoryImpl(this._rest);

  final Dio _rest;

  Future<ApiResult<T>> _rpc<T>(String name, Map<String, dynamic> body, T Function(Object? data) read) async {
    try {
      final r = await _rest.post('/rpc/$name', data: body);
      return ApiSuccess(read(r.data));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  @override
  Future<ApiResult<List<SupplierCard>>> cards({String? search}) => _rpc(
      'supplier_cards',
      {'p_search': (search?.trim().isEmpty ?? true) ? null : search!.trim()},
      (d) => [for (final e in (d is List ? d : const []).whereType<Map>()) SupplierCard.fromJson(e.cast<String, dynamic>())]);

  @override
  Future<ApiResult<SupplierHistory>> history(int supplierId, {int? warehouseId}) => _rpc(
      'supplier_purchase_history',
      {'p_supplier_id': supplierId, 'p_warehouse_id': warehouseId},
      (d) => SupplierHistory.fromJson((d as Map).cast<String, dynamic>()));
}

final supplierHistoryRepositoryProvider =
    Provider<SupplierHistoryRepository>((ref) => SupplierHistoryRepositoryImpl(ref.watch(restDioProvider)));

final supplierCardsProvider = FutureProvider.autoDispose<List<SupplierCard>>((ref) async {
  final r = await ref.watch(supplierHistoryRepositoryProvider).cards();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// One supplier's history, with stock in the warehouse chosen at the top.
final supplierHistoryProvider = FutureProvider.autoDispose.family<SupplierHistory, int>((ref, supplierId) async {
  final wh = ref.watch(activeWarehouseIdProvider);
  final r = await ref.watch(supplierHistoryRepositoryProvider).history(supplierId, warehouseId: wh);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
