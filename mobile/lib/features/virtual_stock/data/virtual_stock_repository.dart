import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/virtual_stock.dart';

/// The virtual ledger for warehouses abroad (0088). Nothing here is real
/// stock: it is never available, reserved or shipped.
abstract class VirtualStockRepository {
  Future<ApiResult<List<VirtualWarehouse>>> warehouses();

  Future<ApiResult<VirtualStockSummary>> summary(int warehouseId,
      {required DateTime from, required DateTime to});

  Future<ApiResult<List<VirtualStockEntry>>> history(int warehouseId, int productId);

  /// A count ("on this day there were N") or a known change (+/-).
  Future<ApiResult<int>> record({
    required int warehouseId,
    required String janCode,
    required VirtualEntryType type,
    required int quantity,
    DateTime? occurredOn,
    String? note,
  });

  Future<ApiResult<bool>> delete(int entryId);
}

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class VirtualStockRepositoryImpl implements VirtualStockRepository {
  VirtualStockRepositoryImpl(this._dio);

  final Dio _dio;

  static List<Map<String, dynamic>> _rows(dynamic data) {
    final rows = data is List
        ? (data.length == 1 && data.first is List ? data.first as List : data)
        : const [];
    return rows.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  @override
  Future<ApiResult<List<VirtualWarehouse>>> warehouses() async {
    try {
      final response = await _dio.post('/rpc/virtual_stock_warehouses', data: const {});
      return ApiSuccess(_rows(response.data).map(VirtualWarehouse.fromJson).toList());
    } on DioException catch (e) {
      return mapDioError<List<VirtualWarehouse>>(e);
    }
  }

  @override
  Future<ApiResult<VirtualStockSummary>> summary(int warehouseId,
      {required DateTime from, required DateTime to}) async {
    try {
      final response = await _dio.post('/rpc/virtual_stock_summary', data: {
        'p_warehouse_id': warehouseId,
        'p_from': _day(from),
        'p_to': _day(to),
      });
      final data = response.data;
      final json = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(
          VirtualStockSummary.fromJson((json as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<VirtualStockSummary>(e);
    }
  }

  @override
  Future<ApiResult<List<VirtualStockEntry>>> history(int warehouseId, int productId) async {
    try {
      final response = await _dio.post('/rpc/virtual_stock_history', data: {
        'p_warehouse_id': warehouseId,
        'p_product_id': productId,
      });
      return ApiSuccess(_rows(response.data).map(VirtualStockEntry.fromJson).toList());
    } on DioException catch (e) {
      return mapDioError<List<VirtualStockEntry>>(e);
    }
  }

  @override
  Future<ApiResult<int>> record({
    required int warehouseId,
    required String janCode,
    required VirtualEntryType type,
    required int quantity,
    DateTime? occurredOn,
    String? note,
  }) async {
    try {
      final response = await _dio.post('/rpc/record_virtual_stock', data: {
        'p_warehouse_id': warehouseId,
        'p_jan_code': janCode,
        'p_entry_type': type.wire,
        'p_quantity': quantity,
        'p_occurred_on': occurredOn == null ? null : _day(occurredOn),
        'p_note': note,
      });
      final id = response.data;
      return ApiSuccess(id is int ? id : int.tryParse('$id') ?? 0);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<bool>> delete(int entryId) async {
    try {
      final response =
          await _dio.post('/rpc/delete_virtual_stock_entry', data: {'p_id': entryId});
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
