import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/documents.dart';

/// Supplier invoices and the four-way match (0108).
abstract class DocumentsRepository {
  Future<ApiResult<DocumentMatch>> match(int purchaseOrderId);
  Future<ApiResult<List<DocumentException>>> exceptions({int? warehouseId});
  Future<ApiResult<List<SupplierInvoice>>> invoices({int? purchaseOrderId});
  Future<ApiResult<SupplierInvoice>> invoice(int id);
  Future<ApiResult<InvoiceSaveResult>> save(SupplierInvoice invoice);

  /// approved / void / open. Returns how many supply terms took its prices.
  Future<ApiResult<int>> setStatus(int id, InvoiceStatus status, {String? note});
  Future<ApiResult<bool>> setTolerance(int partnerId, double qtyPct, double pricePct);
}

dynamic _one(dynamic d) => d is List && d.length == 1 && (d.first is Map || d.first is List) ? d.first : d;

class DocumentsRepositoryImpl implements DocumentsRepository {
  DocumentsRepositoryImpl(this._dio);

  final Dio _dio;

  Future<ApiResult<T>> _rpc<T>(String name, Map<String, dynamic> body, T Function(dynamic) parse) async {
    try {
      final r = await _dio.post('/rpc/$name', data: body);
      return ApiSuccess(parse(_one(r.data)));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  List<Map<String, dynamic>> _list(dynamic d) => [
        for (final e in (d as List? ?? const []))
          if (e is Map) e.cast<String, dynamic>(),
      ];

  @override
  Future<ApiResult<DocumentMatch>> match(int purchaseOrderId) => _rpc('document_match', {'p_purchase_order_id': purchaseOrderId},
      (d) => DocumentMatch.fromJson((d as Map).cast<String, dynamic>()));

  @override
  Future<ApiResult<List<DocumentException>>> exceptions({int? warehouseId}) =>
      _rpc('document_exceptions', {'p_warehouse_id': warehouseId, 'p_days': 180},
          (d) => [for (final r in _list(d)) DocumentException.fromJson(r)]);

  @override
  Future<ApiResult<List<SupplierInvoice>>> invoices({int? purchaseOrderId}) =>
      _rpc('list_supplier_invoices', {'p_purchase_order_id': purchaseOrderId, 'p_status': null},
          (d) => [for (final r in _list(d)) SupplierInvoice.fromJson(r)]);

  @override
  Future<ApiResult<SupplierInvoice>> invoice(int id) =>
      _rpc('supplier_invoice', {'p_id': id}, (d) => SupplierInvoice.fromJson((d as Map).cast<String, dynamic>()));

  @override
  Future<ApiResult<InvoiceSaveResult>> save(SupplierInvoice invoice) =>
      _rpc('save_supplier_invoice', {'p': invoice.toJson()}, (d) => InvoiceSaveResult.fromJson((d as Map).cast<String, dynamic>()));

  @override
  Future<ApiResult<int>> setStatus(int id, InvoiceStatus status, {String? note}) =>
      _rpc('set_supplier_invoice_status', {'p_id': id, 'p_status': status.wire, 'p_note': note},
          (d) => ((d as Map)['terms_updated'] as num?)?.toInt() ?? 0);

  @override
  Future<ApiResult<bool>> setTolerance(int partnerId, double qtyPct, double pricePct) =>
      _rpc('set_supplier_match_rule', {'p_partner_id': partnerId, 'p_qty_pct': qtyPct, 'p_price_pct': pricePct, 'p_note': null},
          (_) => true);
}
