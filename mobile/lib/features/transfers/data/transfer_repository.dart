import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/transfer_order.dart';

/// The completed-receiving result: the refreshed order plus what it changed.
class CompletedTransfer {
  const CompletedTransfer(this.order, this.summary);
  final TransferOrder order;
  final TransferReceiveSummary summary;
}

/// Draft line for creating a transfer: what to move and how much.
class TransferLineDraft {
  const TransferLineDraft({
    required this.janCode,
    required this.quantity,
    this.productName,
  });
  final String janCode;
  final int quantity;
  final String? productName;

  Map<String, dynamic> toJson() => {
        'jan_code': janCode,
        'quantity': quantity,
        if (productName != null && productName!.isNotEmpty)
          'product_name': productName,
      };
}

/// Inter-warehouse transfer over the `transfers` edge function. Stock moves
/// exactly twice per transfer — out at the source when picking completes, in
/// at the destination when receiving completes — both inside RPCs server-side.
abstract class TransferRepository {
  Future<ApiResult<List<TransferOrder>>> list({int? warehouseId, String? status});
  Future<ApiResult<TransferOrder>> show(int id);

  Future<ApiResult<TransferOrder>> create({
    required int sourceWarehouseId,
    required int destinationWarehouseId,
    required List<TransferLineDraft> lines,
    String? note,
  });

  Future<ApiResult<TransferOrder>> submit(int id);
  Future<ApiResult<TransferOrder>> approve(int id);
  Future<ApiResult<TransferOrder>> reject(int id, {String? reason});
  Future<ApiResult<TransferOrder>> cancel(int id);

  Future<ApiResult<TransferOrder>> startPicking(int id);
  Future<ApiResult<TransferOrder>> recordPick(int lineId, int quantity);
  Future<ApiResult<TransferOrder>> completePicking(int id);

  Future<ApiResult<TransferOrder>> startReceiving(int id);
  Future<ApiResult<TransferOrder>> recordReceipt(int lineId, int quantity);
  Future<ApiResult<CompletedTransfer>> completeReceiving(int id);
}

class TransferRepositoryImpl implements TransferRepository {
  TransferRepositoryImpl(this._dio);

  final Dio _dio;

  TransferOrder _order(dynamic body) => TransferOrder.fromJson(
      ((body as Map)['data'] as Map).cast<String, dynamic>());

  Future<ApiResult<TransferOrder>> _post(String path, [Map<String, dynamic>? data]) async {
    try {
      final response = await _dio.post(path, data: data);
      return ApiSuccess(_order(response.data));
    } on DioException catch (e) {
      return mapDioError<TransferOrder>(e);
    }
  }

  Future<ApiResult<TransferOrder>> _patch(String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch(path, data: data);
      return ApiSuccess(_order(response.data));
    } on DioException catch (e) {
      return mapDioError<TransferOrder>(e);
    }
  }

  @override
  Future<ApiResult<List<TransferOrder>>> list({int? warehouseId, String? status}) async {
    try {
      final response = await _dio.get('/transfers', queryParameters: {
        if (warehouseId != null) 'warehouse_id': warehouseId,
        if (status != null) 'status': status,
      });
      final rows = (response.data as Map)['data'] as List? ?? const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => TransferOrder.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<TransferOrder>>(e);
    }
  }

  @override
  Future<ApiResult<TransferOrder>> show(int id) async {
    try {
      final response = await _dio.get('/transfers/$id');
      return ApiSuccess(_order(response.data));
    } on DioException catch (e) {
      return mapDioError<TransferOrder>(e);
    }
  }

  @override
  Future<ApiResult<TransferOrder>> create({
    required int sourceWarehouseId,
    required int destinationWarehouseId,
    required List<TransferLineDraft> lines,
    String? note,
  }) =>
      _post('/transfers', {
        'source_warehouse_id': sourceWarehouseId,
        'destination_warehouse_id': destinationWarehouseId,
        'lines': lines.map((l) => l.toJson()).toList(),
        if (note != null && note.isNotEmpty) 'note': note,
      });

  @override
  Future<ApiResult<TransferOrder>> submit(int id) => _post('/transfers/$id/submit');

  @override
  Future<ApiResult<TransferOrder>> approve(int id) => _post('/transfers/$id/approve');

  @override
  Future<ApiResult<TransferOrder>> reject(int id, {String? reason}) =>
      _post('/transfers/$id/reject',
          {if (reason != null && reason.isNotEmpty) 'reason': reason});

  @override
  Future<ApiResult<TransferOrder>> cancel(int id) => _post('/transfers/$id/cancel');

  @override
  Future<ApiResult<TransferOrder>> startPicking(int id) =>
      _post('/transfers/$id/start-picking');

  @override
  Future<ApiResult<TransferOrder>> recordPick(int lineId, int quantity) =>
      _patch('/transfers/lines/$lineId/pick', {'quantity': quantity});

  @override
  Future<ApiResult<TransferOrder>> completePicking(int id) =>
      _post('/transfers/$id/complete-picking');

  @override
  Future<ApiResult<TransferOrder>> startReceiving(int id) =>
      _post('/transfers/$id/start-receiving');

  @override
  Future<ApiResult<TransferOrder>> recordReceipt(int lineId, int quantity) =>
      _patch('/transfers/lines/$lineId/receive', {'quantity': quantity});

  @override
  Future<ApiResult<CompletedTransfer>> completeReceiving(int id) async {
    try {
      final response = await _dio.post('/transfers/$id/complete-receiving');
      final body = response.data as Map;
      return ApiSuccess(CompletedTransfer(
        TransferOrder.fromJson((body['data'] as Map).cast<String, dynamic>()),
        TransferReceiveSummary.fromJson(
            (body['summary'] as Map? ?? const {}).cast<String, dynamic>()),
      ));
    } on DioException catch (e) {
      return mapDioError<CompletedTransfer>(e);
    }
  }
}
