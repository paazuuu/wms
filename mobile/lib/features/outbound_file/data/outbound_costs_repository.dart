import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart' show mimeTypeFor;
import '../../delivery/application/delivery_providers.dart';

const costEvidenceBucket = 'cost-evidence';

/// 'freight' (輸送費) or 'fee' (委託手数料).
enum OutboundCostKind {
  freight,
  fee;

  static OutboundCostKind of(String? s) => s == 'fee' ? fee : freight;
}

/// A bill kept as the evidence of a list's freight or fee (0214).
class OutboundCostFile extends Equatable {
  const OutboundCostFile({
    required this.id,
    required this.kind,
    required this.storagePath,
    required this.fileName,
    this.contentType,
    this.byteSize,
    this.uploadedAt,
    this.uploadedByName,
  });

  final int id;
  final OutboundCostKind kind;
  final String storagePath;
  final String fileName;
  final String? contentType;
  final int? byteSize;
  final DateTime? uploadedAt;
  final String? uploadedByName;

  String get mime => (contentType ?? '').isNotEmpty ? contentType! : mimeTypeFor(fileName);

  factory OutboundCostFile.fromJson(Map<String, dynamic> j) => OutboundCostFile(
        id: (j['id'] as num).toInt(),
        kind: OutboundCostKind.of(j['cost_kind'] as String?),
        storagePath: '${j['storage_path'] ?? ''}',
        fileName: '${j['file_name'] ?? ''}',
        contentType: j['content_type'] as String?,
        byteSize: (j['byte_size'] as num?)?.toInt(),
        uploadedAt: DateTime.tryParse('${j['uploaded_at'] ?? ''}')?.toLocal(),
        uploadedByName: j['uploaded_by_name'] as String?,
      );

  @override
  List<Object?> get props => [id, kind, storagePath, fileName];
}

/// The amounts the AI read off a bill: before tax, the tax and the total.
typedef BillTotals = ({double? subtotal, double? tax, double? total});

/// 輸送費 and the bills behind a list's costs (0214).
abstract class OutboundCostsRepository {
  Future<ApiResult<bool>> setFreight(int fileId, double? amount);

  /// Keeps [bytes] as the evidence of [kind] on the list.
  Future<ApiResult<OutboundCostFile>> addEvidence({
    required int fileId,
    required int warehouseId,
    required OutboundCostKind kind,
    required String name,
    required Uint8List bytes,
  });

  /// Takes a bill off the list (the file is kept).
  Future<ApiResult<bool>> removeEvidence(int id);

  Future<ApiResult<Uint8List>> evidenceBytes(String storagePath);

  /// The amounts on a kept bill, read by the AI; null when none were found.
  Future<ApiResult<BillTotals?>> readAmount(int costFileId);
}

class OutboundCostsRepositoryImpl implements OutboundCostsRepository {
  OutboundCostsRepositoryImpl(this._rest, this._storage, this._functions);

  final Dio _rest;
  final Dio _storage;
  final Dio _functions;

  @override
  Future<ApiResult<bool>> setFreight(int fileId, double? amount) async {
    try {
      await _rest.post('/rpc/outbound_file_set_freight', data: {'p_id': fileId, 'p_amount': amount});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<OutboundCostFile>> addEvidence({
    required int fileId,
    required int warehouseId,
    required OutboundCostKind kind,
    required String name,
    required Uint8List bytes,
  }) async {
    final safe = name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path = '$warehouseId/$fileId/${DateTime.now().millisecondsSinceEpoch}-$safe';
    final type = mimeTypeFor(name);
    try {
      await _storage.post('/object/$costEvidenceBucket/$path', data: bytes, options: Options(headers: {'Content-Type': type}));
      final r = await _rest.post('/rpc/outbound_cost_file_add', data: {
        'p_file_id': fileId,
        'p_kind': kind.name,
        'p_path': path,
        'p_name': name,
        'p_type': type,
        'p_size': bytes.length,
      });
      return ApiSuccess(OutboundCostFile(
        id: (r.data as num).toInt(),
        kind: kind,
        storagePath: path,
        fileName: name,
        contentType: type,
        byteSize: bytes.length,
        uploadedAt: DateTime.now(),
      ));
    } on DioException catch (e) {
      return mapDioError<OutboundCostFile>(e);
    }
  }

  @override
  Future<ApiResult<bool>> removeEvidence(int id) async {
    try {
      final r = await _rest.post('/rpc/outbound_cost_file_remove', data: {'p_id': id});
      return ApiSuccess(r.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<Uint8List>> evidenceBytes(String storagePath) async {
    try {
      final r = await _storage.get<List<int>>('/object/authenticated/$costEvidenceBucket/$storagePath',
          options: Options(responseType: ResponseType.bytes));
      return ApiSuccess(Uint8List.fromList(r.data ?? const []));
    } on DioException catch (e) {
      return mapDioError<Uint8List>(e);
    }
  }

  @override
  Future<ApiResult<BillTotals?>> readAmount(int costFileId) async {
    try {
      final r = await _functions.post(
        '/import-plan',
        data: {'mode': 'read_cost', 'cost_file_id': costFileId},
        options: Options(contentType: Headers.jsonContentType, receiveTimeout: const Duration(seconds: 150)),
      );
      final data = ((r.data as Map?)?['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      final t = (data['totals'] as Map?)?.cast<String, dynamic>();
      double? d(Object? v) => v is num ? v.toDouble() : null;
      if (t == null) return const ApiSuccess(null);
      final out = (subtotal: d(t['doc_subtotal']), tax: d(t['doc_tax']), total: d(t['doc_total']));
      return ApiSuccess(out.subtotal == null && out.total == null ? null : out);
    } on DioException catch (e) {
      return mapDioError<BillTotals?>(e);
    }
  }
}

final outboundCostsRepositoryProvider = Provider<OutboundCostsRepository>((ref) => OutboundCostsRepositoryImpl(
    ref.watch(restDioProvider), ref.watch(storageDioProvider), ref.watch(deliveryDioProvider)));
