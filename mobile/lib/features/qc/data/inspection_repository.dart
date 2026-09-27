import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/bulk_inspection.dart';
import '../domain/delivery_note.dart';
import '../domain/held_stock.dart';
import '../domain/inspection.dart';

/// Inbound inspection (検品) over the `inspections` edge function. The tables
/// are read-only to the client, so every mutation goes through the function.
abstract class InspectionRepository {
  Future<ApiResult<List<Inspection>>> list({String? status, int? warehouseId});
  Future<ApiResult<Inspection>> show(int id);

  /// Opens (or returns) the inspection for a receipt — idempotent server-side.
  Future<ApiResult<Inspection>> start(int reconciliationId);

  Future<ApiResult<Inspection>> saveItem(
      int inspectionId, int itemId, InspectionFinding finding);

  Future<ApiResult<Inspection>> complete(int inspectionId,
      {String? note, String? failStatus});

  /// `held_stock` (0098): parcels on hand that cannot ship — waiting for
  /// inspection, or held / quarantined / damaged / expired / blocked. [status]
  /// narrows it to one status. Read straight off the RPC rather than through
  /// the edge function, because it is a read and scopes itself.
  Future<ApiResult<List<HeldStock>>> heldStock({int? warehouseId, String? status});

  /// `open_inspection_lines` (0099): every line still to settle, for the bulk
  /// screen to group by arrival date, purchase order and product.
  Future<ApiResult<List<OpenInspectionLine>>> openLines({int? warehouseId});

  /// `pass_inspection_items` (0099): the chosen lines passed in full and
  /// settled at once — their goods become shippable, the rest stay open.
  Future<ApiResult<BulkPassResult>> passItems(List<int> itemIds, {String? note});

  /// `record_inspection_count` (0100): what the inspector counted for a line.
  /// [add] adds [quantity] to the count so far — one scan, one piece.
  Future<ApiResult<InspectionCount>> recordCount(int itemId, int quantity,
      {InspectionCountMode mode = InspectionCountMode.set});

  /// `apply_delivery_note` (0101): the delivery note's lines laid against the
  /// inspection — each matched line gets the note's figure.
  Future<ApiResult<DeliveryNoteApplyResult>> applyDeliveryNote(
      int inspectionId, List<DeliveryNoteLine> lines);

  /// `report_inspection_wrong_item` (0100): a product found in the delivery
  /// that is not on it, recorded as 誤品 for someone to deal with.
  Future<ApiResult<bool>> reportWrongItem(int inspectionId, String janCode,
      {int quantity = 1, String? note});

  /// `convert_inspection_item` (0103): a line the supplier's writing did not
  /// match is booked under our [productId]; with [remember] the supplier's
  /// JAN, 品番, name and maker are kept so their next delivery converts itself.
  Future<ApiResult<bool>> convertItem(int itemId, int productId, {bool remember = true});

  /// `dispose_held_stock` (0098): one decision on one bucket of held goods.
  Future<ApiResult<DispositionResult>> dispose(
    HeldStock row,
    HeldDisposition action, {
    required int quantity,
    String? note,
  });
}

class InspectionRepositoryImpl implements InspectionRepository {
  /// Two clients, because this repository spans two doors. The inspection
  /// writes go through the edge function (`_dio`), which is the only gate in
  /// front of RPCs granted to `service_role` alone; the held-stock read is an
  /// ordinary guarded RPC and goes straight to PostgREST (`_restDio`).
  InspectionRepositoryImpl(this._dio, {Dio? restDio})
      : _restDio = restDio ?? _dio;

  final Dio _dio;
  final Dio _restDio;

  Inspection _one(dynamic responseData) => Inspection.fromJson(
      ((responseData as Map)['data'] as Map).cast<String, dynamic>());

  @override
  Future<ApiResult<List<Inspection>>> list(
      {String? status, int? warehouseId}) async {
    try {
      final response = await _dio.get('/inspections', queryParameters: {
        if (status != null) 'status': status,
        if (warehouseId != null) 'warehouse_id': warehouseId,
      });
      final rows = (response.data as Map)['data'] as List? ?? const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => Inspection.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<Inspection>>(e);
    }
  }

  @override
  Future<ApiResult<Inspection>> show(int id) async {
    try {
      final response = await _dio.get('/inspections/$id');
      return ApiSuccess(_one(response.data));
    } on DioException catch (e) {
      return mapDioError<Inspection>(e);
    }
  }

  @override
  Future<ApiResult<Inspection>> start(int reconciliationId) async {
    try {
      final response = await _dio.post('/inspections',
          data: {'reconciliation_id': reconciliationId});
      return ApiSuccess(_one(response.data));
    } on DioException catch (e) {
      return mapDioError<Inspection>(e);
    }
  }

  @override
  Future<ApiResult<Inspection>> saveItem(
      int inspectionId, int itemId, InspectionFinding finding) async {
    try {
      final response = await _dio.patch(
        '/inspections/$inspectionId/items/$itemId',
        data: finding.toJson(),
      );
      return ApiSuccess(_one(response.data));
    } on DioException catch (e) {
      return mapDioError<Inspection>(e);
    }
  }

  @override
  Future<ApiResult<Inspection>> complete(int inspectionId,
      {String? note, String? failStatus}) async {
    try {
      final response = await _dio.post(
        '/inspections/$inspectionId/complete',
        data: {
          if (note != null && note.isNotEmpty) 'note': note,
          if (failStatus != null && failStatus.isNotEmpty)
            'fail_status': failStatus,
        },
      );
      return ApiSuccess(_one(response.data));
    } on DioException catch (e) {
      return mapDioError<Inspection>(e);
    }
  }

  @override
  Future<ApiResult<List<HeldStock>>> heldStock({int? warehouseId, String? status}) async {
    try {
      final response = await _restDio.post('/rpc/held_stock', data: {
        'p_warehouse_id': warehouseId,
        'p_status': status,
      });
      final data = response.data;
      final list = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(list
          .whereType<Map>()
          .map((e) => HeldStock.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false));
    } on DioException catch (e) {
      return mapDioError<List<HeldStock>>(e);
    }
  }

  @override
  Future<ApiResult<DispositionResult>> dispose(
    HeldStock row,
    HeldDisposition action, {
    required int quantity,
    String? note,
  }) async {
    try {
      final response = await _restDio.post('/rpc/dispose_held_stock', data: {
        'p_warehouse_id': row.warehouseId,
        'p_product_id': row.productId,
        'p_from_status': row.statusCode,
        'p_action': action.wire,
        'p_quantity': quantity,
        'p_lot_id': row.lotId,
        'p_serial_id': row.serialId,
        'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      });
      final data = response.data;
      final map = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(DispositionResult.fromJson((map as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<DispositionResult>(e);
    }
  }

  @override
  Future<ApiResult<List<OpenInspectionLine>>> openLines({int? warehouseId}) async {
    try {
      final response = await _restDio.post('/rpc/open_inspection_lines', data: {
        'p_warehouse_id': warehouseId,
      });
      final data = response.data;
      final list = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(list
          .whereType<Map>()
          .map((e) => OpenInspectionLine.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false));
    } on DioException catch (e) {
      return mapDioError<List<OpenInspectionLine>>(e);
    }
  }

  @override
  Future<ApiResult<BulkPassResult>> passItems(List<int> itemIds, {String? note}) async {
    try {
      final response = await _restDio.post('/rpc/pass_inspection_items', data: {
        'p_item_ids': itemIds,
        'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      });
      final data = response.data;
      final map = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(BulkPassResult.fromJson((map as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<BulkPassResult>(e);
    }
  }

  @override
  Future<ApiResult<InspectionCount>> recordCount(int itemId, int quantity,
      {InspectionCountMode mode = InspectionCountMode.set}) async {
    try {
      final response = await _restDio.post('/rpc/record_inspection_count', data: {
        'p_item_id': itemId,
        'p_quantity': quantity,
        'p_mode': mode.wire,
      });
      final data = response.data;
      final map = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(InspectionCount.fromJson((map as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<InspectionCount>(e);
    }
  }

  @override
  Future<ApiResult<DeliveryNoteApplyResult>> applyDeliveryNote(
      int inspectionId, List<DeliveryNoteLine> lines) async {
    try {
      final response = await _restDio.post('/rpc/apply_delivery_note', data: {
        'p_inspection_id': inspectionId,
        'p_lines': [for (final l in lines) l.toJson()],
      });
      final data = response.data;
      final map = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(
          DeliveryNoteApplyResult.fromJson((map as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<DeliveryNoteApplyResult>(e);
    }
  }

  @override
  Future<ApiResult<bool>> reportWrongItem(int inspectionId, String janCode,
      {int quantity = 1, String? note}) async {
    try {
      await _restDio.post('/rpc/report_inspection_wrong_item', data: {
        'p_inspection_id': inspectionId,
        'p_jan_code': janCode,
        'p_quantity': quantity,
        'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> convertItem(int itemId, int productId, {bool remember = true}) async {
    try {
      await _restDio.post('/rpc/convert_inspection_item', data: {
        'p_item_id': itemId,
        'p_product_id': productId,
        'p_remember': remember,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
