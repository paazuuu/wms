import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/delivery_plan.dart';
import '../domain/reconciliation.dart';
import '../domain/receipt.dart';

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

/// Summary returned after committing a plan.
class PlanImportResult {
  const PlanImportResult({
    required this.planId,
    required this.lineCount,
    required this.totalQuantity,
    this.source = '',
    this.needsReview = false,
    this.referenceNo,
  });

  final int planId;
  final int lineCount;
  final int totalQuantity;
  final String source;

  /// The company could not be identified, so the plan landed in the UNKNOWN
  /// reference series and wants a manual supplier assignment.
  final bool needsReview;

  /// Per-company reference assigned at import, e.g. "ABC-00001".
  final String? referenceNo;

  factory PlanImportResult.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    return PlanImportResult(
      planId: asInt(json['plan_id']),
      lineCount: asInt(json['line_count']),
      totalQuantity: asInt(json['total_quantity']),
      source: json['source'] as String? ?? '',
      needsReview: json['needs_review'] == true,
      referenceNo: json['reference_no'] as String?,
    );
  }
}

/// The auto-read header + parsed lines returned by the preview step, before the
/// operator confirms. Every header field is nullable — a null means the note
/// could not be read there and the operator should fill it in.
class ImportPreview {
  const ImportPreview({
    required this.source,
    required this.lineCount,
    required this.totalQuantity,
    required this.lines,
    this.supplierName,
    this.supplierCode,
    this.registrationNumber,
    this.customerCode,
    this.docNumber,
    this.docDate,
    this.deliveryNumber,
    this.orderDate,
  });

  final String source;
  final int lineCount;
  final int totalQuantity;

  /// Raw aggregated lines, sent back verbatim on commit so nothing is re-parsed.
  final List<Map<String, dynamic>> lines;

  final String? supplierName;
  final String? supplierCode;
  final String? registrationNumber;
  final String? customerCode;
  final String? docNumber;
  final String? docDate;
  final String? deliveryNumber;
  final String? orderDate;

  factory ImportPreview.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    final header = (json['header'] as Map<String, dynamic>?) ?? const {};
    String? s(dynamic v) {
      if (v == null) return null;
      final t = v.toString().trim();
      return t.isEmpty ? null : t;
    }

    return ImportPreview(
      source: json['source'] as String? ?? '',
      lineCount: asInt(json['line_count']),
      totalQuantity: asInt(json['total_quantity']),
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      supplierName: s(header['supplier_name']),
      supplierCode: s(json['supplier_code']),
      registrationNumber: s(header['registration_number']),
      customerCode: s(header['customer_code']),
      docNumber: s(header['doc_number']),
      docDate: s(header['doc_date']),
      deliveryNumber: s(json['delivery_number']),
      orderDate: s(json['order_date']),
    );
  }
}

/// The reviewed header the operator confirms on commit.
class PlanCommit {
  const PlanCommit({
    required this.deliveryNumber,
    required this.lines,
    this.supplier,
    this.supplierCode,
    this.registrationNumber,
    this.customerCode,
    this.docNumber,
    this.orderDate,
    this.source,
  });

  final String deliveryNumber;
  final List<Map<String, dynamic>> lines;
  final String? supplier;
  final String? supplierCode;
  final String? registrationNumber;
  final String? customerCode;
  final String? docNumber;
  final String? orderDate;
  final String? source;

  Map<String, dynamic> toJson() {
    String? clean(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    return {
      'delivery_number': deliveryNumber.trim(),
      if (clean(supplier) != null) 'supplier': clean(supplier),
      if (clean(supplierCode) != null) 'supplier_code': clean(supplierCode),
      if (clean(registrationNumber) != null)
        'registration_number': clean(registrationNumber),
      if (clean(customerCode) != null) 'customer_code': clean(customerCode),
      if (clean(docNumber) != null) 'doc_number': clean(docNumber),
      if (clean(orderDate) != null) 'order_date': clean(orderDate),
      if (clean(source) != null) 'source': clean(source),
      'lines': lines,
    };
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

  /// Upload a supplier's Excel/PDF/image; the backend parses it, auto-reads the
  /// delivery-note header, and returns it for review WITHOUT saving anything.
  Future<ApiResult<ImportPreview>> previewPlan({
    required MultipartFile file,
    String? deliveryNumber,
    String? supplier,
    String? supplierCode,
  });

  /// Save the plan with the reviewed (possibly edited) header and lines.
  Future<ApiResult<PlanImportResult>> commitPlan(PlanCommit commit);

  /// The receipts recorded against a plan, newest first.
  Future<ApiResult<List<Receipt>>> receipts(int planId);

  /// Void a receipt: reverse its received quantities and stock, and recompute
  /// the plan status. Returns the updated plan.
  Future<ApiResult<DeliveryPlan>> cancelReceipt(int planId, int receiptId);
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
  Future<ApiResult<ImportPreview>> previewPlan({
    required MultipartFile file,
    String? deliveryNumber,
    String? supplier,
    String? supplierCode,
  }) async {
    try {
      final form = FormData();
      form.files.add(MapEntry('file', file));
      form.fields.add(const MapEntry('dry_run', '1'));
      if (deliveryNumber != null && deliveryNumber.trim().isNotEmpty) {
        form.fields.add(MapEntry('delivery_number', deliveryNumber.trim()));
      }
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
      return ApiSuccess(ImportPreview.fromJson(
          response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<ImportPreview>(e);
    }
  }

  @override
  Future<ApiResult<PlanImportResult>> commitPlan(PlanCommit commit) async {
    try {
      final response = await _dio.post(
        '/import-plan',
        data: commit.toJson(),
        options: Options(
          contentType: Headers.jsonContentType,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return ApiSuccess(PlanImportResult.fromJson(
          response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<PlanImportResult>(e);
    }
  }

  @override
  Future<ApiResult<List<Receipt>>> receipts(int planId) async {
    try {
      final response = await _dio.get('/delivery-plans/$planId/receipts');
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => Receipt.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<Receipt>>(e);
    }
  }

  @override
  Future<ApiResult<DeliveryPlan>> cancelReceipt(
      int planId, int receiptId) async {
    try {
      final response = await _dio
          .post('/delivery-plans/$planId/receipts/$receiptId/cancel');
      return ApiSuccess(
          DeliveryPlan.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<DeliveryPlan>(e);
    }
  }
}
