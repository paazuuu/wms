import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/delivery_plan.dart';
import '../domain/reconciliation.dart';

/// One counted line submitted at the end of a reconciliation session.
class ReconcileEntry {
  const ReconcileEntry({
    required this.janCode,
    required this.actualQuantity,
    required this.source,
    this.lineId,
  });

  /// Plan line id when this JAN was on the plan; null for an unexpected arrival.
  final int? lineId;
  final String janCode;
  final int actualQuantity;
  final CountSource source;

  Map<String, dynamic> toJson() => {
        if (lineId != null) 'line_id': lineId,
        'jan_code': janCode,
        'actual_quantity': actualQuantity,
        'source': source.wire,
      };
}

/// Summary returned after importing a plan from an uploaded file.
class PlanImportResult {
  const PlanImportResult({
    required this.planId,
    required this.lineCount,
    required this.totalQuantity,
    this.source = '',
  });

  final int planId;
  final int lineCount;
  final int totalQuantity;
  final String source;

  factory PlanImportResult.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    return PlanImportResult(
      planId: asInt(json['plan_id']),
      lineCount: asInt(json['line_count']),
      totalQuantity: asInt(json['total_quantity']),
      source: json['source'] as String? ?? '',
    );
  }
}

/// Data access for the delivery-plan reconciliation flow.
///
/// Delivery plans are imported from the supplier's Excel on the back office, so
/// the mobile client only reads plans and submits the reconciliation result —
/// it never creates a plan. The shared backend is what lets one person import
/// the Excel and another do the physical check.
abstract class DeliveryRepository {
  Future<ApiResult<List<DeliveryPlan>>> list({String? status, String? search});
  Future<ApiResult<DeliveryPlan>> show(int id);
  Future<ApiResult<DeliveryPlan>> reconcile(
    int id, {
    required List<ReconcileEntry> entries,
    String? noteReference,
    bool complete = true,
  });

  /// Upload a supplier's Excel/PDF/image; the backend parses it, normalizes,
  /// and creates a delivery plan. Returns a summary of what was imported.
  Future<ApiResult<PlanImportResult>> importPlan({
    required MultipartFile file,
    required String deliveryNumber,
    String? supplier,
    String? supplierCode,
  });
}

class DeliveryRepositoryImpl implements DeliveryRepository {
  DeliveryRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<DeliveryPlan>>> list(
      {String? status, String? search}) async {
    try {
      final response = await _dio.get('/delivery-plans', queryParameters: {
        if (status != null) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'per_page': 50,
      });
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => DeliveryPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<DeliveryPlan>>(e);
    }
  }

  @override
  Future<ApiResult<DeliveryPlan>> show(int id) async {
    try {
      final response = await _dio.get('/delivery-plans/$id');
      return ApiSuccess(
          DeliveryPlan.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<DeliveryPlan>(e);
    }
  }

  @override
  Future<ApiResult<DeliveryPlan>> reconcile(
    int id, {
    required List<ReconcileEntry> entries,
    String? noteReference,
    bool complete = true,
  }) async {
    try {
      final response = await _dio.post('/delivery-plans/$id/reconcile', data: {
        'complete': complete,
        if (noteReference != null) 'note_reference': noteReference,
        'lines': entries.map((e) => e.toJson()).toList(),
      });
      return ApiSuccess(
          DeliveryPlan.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<DeliveryPlan>(e);
    }
  }

  @override
  Future<ApiResult<PlanImportResult>> importPlan({
    required MultipartFile file,
    required String deliveryNumber,
    String? supplier,
    String? supplierCode,
  }) async {
    try {
      final form = FormData();
      form.files.add(MapEntry('file', file));
      form.fields.add(MapEntry('delivery_number', deliveryNumber));
      if (supplier != null && supplier.trim().isNotEmpty) {
        form.fields.add(MapEntry('supplier', supplier.trim()));
      }
      if (supplierCode != null && supplierCode.trim().isNotEmpty) {
        form.fields.add(MapEntry('supplier_code', supplierCode.trim()));
      }
      final response = await _dio.post(
        '/import-plan',
        data: form,
        options: Options(receiveTimeout: const Duration(seconds: 180)),
      );
      return ApiSuccess(PlanImportResult.fromJson(
          response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<PlanImportResult>(e);
    }
  }
}
