import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../master_import/data/master_import_repository.dart' show masterImportBucket;
import '../domain/stock_file.dart';

/// Stock from a file, on its own (0144).
abstract class StockImportRepository {
  /// The JANs of [jans] that a product in 商品ライブラリー has, with its name.
  Future<ApiResult<Map<String, String>>> known(List<String> jans);

  /// What each of [jans] has in [warehouseId] now (missing = none).
  Future<ApiResult<Map<String, int>>> onHand(int warehouseId, List<String> jans);

  /// The JANs of [jans] in 価格台帳: the item's id and the name it has there.
  Future<ApiResult<Map<String, (int, String)>>> inPriceBook(List<String> jans);

  /// Puts [lines] into [warehouseId], added or set.
  Future<ApiResult<StockFileResult>> apply(int warehouseId, StockFileMode mode, List<StockFileLine> lines,
      {String? fileName, String? fileType});

  /// Keeps the file the stock was read from with its import.
  Future<ApiResult<bool>> keepFile(int importId, String fileName, Uint8List bytes, String contentType);

  /// Notes on the import what the file was read as (0146), by the AI or
  /// cell by cell, so it can be set beside the original later.
  Future<ApiResult<bool>> note(int importId, List<ReadRow> read, {required bool byAi, int? documentId});
}

class StockImportRepositoryImpl implements StockImportRepository {
  StockImportRepositoryImpl({required Dio rest, required Dio storage})
      : _rest = rest,
        _storage = storage;

  final Dio _rest;
  final Dio _storage;

  @override
  Future<ApiResult<Map<String, String>>> known(List<String> jans) async {
    final out = <String, String>{};
    try {
      // A few hundred at a time, so the URL stays short.
      for (var i = 0; i < jans.length; i += 200) {
        final part = jans.sublist(i, i + 200 > jans.length ? jans.length : i + 200);
        final r = await _rest.get('/products', queryParameters: {
          'select': 'jan_code,name',
          'jan_code': 'in.(${part.join(',')})',
        });
        for (final e in (r.data as List? ?? const []).whereType<Map>()) {
          out['${e['jan_code']}'] = '${e['name'] ?? ''}';
        }
      }
      return ApiSuccess(out);
    } on DioException catch (e) {
      return mapDioError<Map<String, String>>(e);
    }
  }

  /// [jans] a few hundred at a time, so the URL stays short.
  Future<List<Map>> _byJan(String table, String select, List<String> jans, [Map<String, dynamic> extra = const {}]) async {
    final out = <Map>[];
    for (var i = 0; i < jans.length; i += 200) {
      final part = jans.sublist(i, i + 200 > jans.length ? jans.length : i + 200);
      final r = await _rest.get('/$table', queryParameters: {'select': select, 'jan_code': 'in.(${part.join(',')})', ...extra});
      out.addAll((r.data as List? ?? const []).whereType<Map>());
    }
    return out;
  }

  @override
  Future<ApiResult<Map<String, int>>> onHand(int warehouseId, List<String> jans) async {
    try {
      final rows = await _byJan('stock_levels', 'jan_code,on_hand', jans, {'warehouse_id': 'eq.$warehouseId'});
      return ApiSuccess({for (final e in rows) '${e['jan_code']}': (e['on_hand'] as num?)?.toInt() ?? 0});
    } on DioException catch (e) {
      return mapDioError<Map<String, int>>(e);
    }
  }

  @override
  Future<ApiResult<Map<String, (int, String)>>> inPriceBook(List<String> jans) async {
    try {
      final rows = await _byJan('price_book_items', 'id,jan_code,name', jans);
      return ApiSuccess({for (final e in rows) '${e['jan_code']}': ((e['id'] as num).toInt(), '${e['name'] ?? ''}')});
    } on DioException catch (e) {
      return mapDioError<Map<String, (int, String)>>(e);
    }
  }

  @override
  Future<ApiResult<StockFileResult>> apply(int warehouseId, StockFileMode mode, List<StockFileLine> lines,
      {String? fileName, String? fileType}) async {
    try {
      final r = await _rest.post('/rpc/stock_file_import', data: {
        'p_warehouse_id': warehouseId,
        'p_mode': mode.wire,
        'p_lines': [for (final l in lines) l.toJson()],
        'p_file_name': fileName,
        'p_file_type': fileType,
      });
      final d = r.data is List && (r.data as List).isNotEmpty ? (r.data as List).first : r.data;
      return ApiSuccess(StockFileResult.fromJson((d as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<StockFileResult>(e);
    }
  }

  @override
  Future<ApiResult<bool>> keepFile(int importId, String fileName, Uint8List bytes, String contentType) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path = 'imports/$importId/original-${DateTime.now().millisecondsSinceEpoch}-$safe';
    try {
      await _storage.post('/object/$masterImportBucket/$path',
          data: bytes, options: Options(headers: {'Content-Type': contentType}));
      final r = await _rest.post('/rpc/stock_file_import_attach', data: {'p_id': importId, 'p_name': fileName, 'p_path': path});
      return ApiSuccess(r.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> note(int importId, List<ReadRow> read, {required bool byAi, int? documentId}) async {
    try {
      final r = await _rest.post('/rpc/stock_file_import_note', data: {
        'p_id': importId,
        'p_read': [for (final row in read) row.toJson()],
        'p_read_by': byAi ? 'ai' : 'sheet',
        'p_document_id': documentId,
      });
      return ApiSuccess(r.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}

final stockImportRepositoryProvider = Provider<StockImportRepository>((ref) => StockImportRepositoryImpl(
      rest: ref.watch(restDioProvider),
      storage: ref.watch(storageDioProvider),
    ));
