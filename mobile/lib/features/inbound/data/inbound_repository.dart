import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/data/delivery_repository.dart';
import '../domain/inbound.dart';

/// The guarded calls of 仕入先ファイル起点の入荷 (0134–0136), straight to
/// PostgREST: each checks the caller's permission and warehouse itself.
abstract class InboundRepository {
  /// `expected_receipt_timeline` — one plan with its receipts, inspections,
  /// documents and history.
  Future<ApiResult<ExpectedReceipt>> timeline(int planId);

  /// `set_expected_receipt` — only the keys in [changes] change; a null
  /// `expected_arrival_date` means 未定. [documentId] is the file that
  /// brought the change, kept among the plan's documents.
  Future<ApiResult<bool>> setExpectedReceipt(int planId, Map<String, dynamic> changes, {int? documentId});

  /// `inbound_duplicates` — plans the same file or document number became.
  Future<ApiResult<List<InboundDuplicate>>> duplicates({
    int? documentId,
    int? supplierId,
    String? supplierName,
    String? docNumber,
  });

  /// `receive_delivery` — one delivery received. A refusal for more than
  /// was expected carries `OVER_RECEIPT [...]` (see [parseOverReceipt]).
  Future<ApiResult<ReceiveOutcome>> receiveDelivery(
    int planId, {
    required List<ReconcileEntry> entries,
    bool complete = false,
    String? noteReference,
    DateTime? arrivedOn,
    OverReceiptChoice? over,
  });

  /// `set_inspection_schedule` — move a pending inspection's date.
  Future<ApiResult<bool>> setInspectionSchedule(int inspectionId, DateTime date);

  /// `inbound_today` — the floor's counts for one warehouse.
  Future<ApiResult<InboundToday>> today(int warehouseId);

  /// `product_match_candidates` — products that may be what each line
  /// means, best first, keyed by the line's index.
  Future<ApiResult<Map<int, List<MatchCandidate>>>> matchCandidates(
    int? partnerId,
    List<Map<String, dynamic>> lines,
  );

  /// `product_inbound_history`.
  Future<ApiResult<ProductInboundHistory>> productHistory(int productId);
}

class InboundRepositoryImpl implements InboundRepository {
  InboundRepositoryImpl(this._dio);

  final Dio _dio;

  Object? _row(Object? data) => data is List && data.length == 1 && data.first is! Map ? data.first : data;

  @override
  Future<ApiResult<ExpectedReceipt>> timeline(int planId) async {
    try {
      final r = await _dio.post('/rpc/expected_receipt_timeline', data: {'p_plan_id': planId});
      return ApiSuccess(ExpectedReceipt.fromJson(Map<String, dynamic>.from(_row(r.data) as Map)));
    } on DioException catch (e) {
      return mapDioError<ExpectedReceipt>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setExpectedReceipt(int planId, Map<String, dynamic> changes, {int? documentId}) async {
    try {
      await _dio.post('/rpc/set_expected_receipt', data: {
        'p_plan_id': planId,
        'p_changes': changes,
        'p_document_id': documentId,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<List<InboundDuplicate>>> duplicates({
    int? documentId,
    int? supplierId,
    String? supplierName,
    String? docNumber,
  }) async {
    try {
      final r = await _dio.post('/rpc/inbound_duplicates', data: {
        'p_document_id': documentId,
        'p_supplier_id': supplierId,
        'p_supplier_name': supplierName,
        'p_doc_number': docNumber,
      });
      final list = _row(r.data) as List? ?? const [];
      return ApiSuccess([
        for (final e in list)
          if (e is Map) InboundDuplicate.fromJson(Map<String, dynamic>.from(e)),
      ]);
    } on DioException catch (e) {
      return mapDioError<List<InboundDuplicate>>(e);
    }
  }

  @override
  Future<ApiResult<ReceiveOutcome>> receiveDelivery(
    int planId, {
    required List<ReconcileEntry> entries,
    bool complete = false,
    String? noteReference,
    DateTime? arrivedOn,
    OverReceiptChoice? over,
  }) async {
    try {
      final r = await _dio.post('/rpc/receive_delivery', data: {
        'p_plan_id': planId,
        'p_lines': [for (final e in entries) e.toJson()],
        'p_complete': complete,
        'p_note_reference': noteReference,
        'p_arrived_on': arrivedOn == null ? null : isoDay(arrivedOn),
        'p_over': over?.wire,
      });
      return ApiSuccess(ReceiveOutcome.fromJson(Map<String, dynamic>.from(_row(r.data) as Map)));
    } on DioException catch (e) {
      return mapDioError<ReceiveOutcome>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setInspectionSchedule(int inspectionId, DateTime date) async {
    try {
      await _dio.post('/rpc/set_inspection_schedule', data: {
        'p_inspection_id': inspectionId,
        'p_date': isoDay(date),
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<InboundToday>> today(int warehouseId) async {
    try {
      final r = await _dio.post('/rpc/inbound_today', data: {'p_warehouse_id': warehouseId});
      return ApiSuccess(InboundToday.fromJson(Map<String, dynamic>.from(_row(r.data) as Map)));
    } on DioException catch (e) {
      return mapDioError<InboundToday>(e);
    }
  }

  @override
  Future<ApiResult<Map<int, List<MatchCandidate>>>> matchCandidates(
    int? partnerId,
    List<Map<String, dynamic>> lines,
  ) async {
    try {
      final r = await _dio.post('/rpc/product_match_candidates', data: {
        'p_partner_id': partnerId,
        'p_lines': lines,
        'p_limit': 3,
      });
      final out = <int, List<MatchCandidate>>{};
      for (final e in (_row(r.data) as List? ?? const [])) {
        if (e is! Map) continue;
        final index = (e['index'] as num?)?.toInt();
        if (index == null) continue;
        out[index] = [
          for (final c in (e['candidates'] as List? ?? const []))
            if (c is Map) MatchCandidate.fromJson(Map<String, dynamic>.from(c)),
        ];
      }
      return ApiSuccess(out);
    } on DioException catch (e) {
      return mapDioError<Map<int, List<MatchCandidate>>>(e);
    }
  }

  @override
  Future<ApiResult<ProductInboundHistory>> productHistory(int productId) async {
    try {
      final r = await _dio.post('/rpc/product_inbound_history', data: {'p_product_id': productId});
      return ApiSuccess(ProductInboundHistory.fromJson(Map<String, dynamic>.from(_row(r.data) as Map)));
    } on DioException catch (e) {
      return mapDioError<ProductInboundHistory>(e);
    }
  }
}
