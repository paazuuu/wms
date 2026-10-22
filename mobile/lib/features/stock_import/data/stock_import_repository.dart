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

  /// Puts [lines] into [warehouseId], added or set.
  Future<ApiResult<StockFileResult>> apply(int warehouseId, StockFileMode mode, List<StockFileLine> lines,
      {String? fileName, String? fileType});

  /// Keeps the file the stock was read from with its import.
  Future<ApiResult<bool>> keepFile(int importId, String fileName, Uint8List bytes, String contentType);
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
}

final stockImportRepositoryProvider = Provider<StockImportRepository>((ref) => StockImportRepositoryImpl(
      rest: ref.watch(restDioProvider),
      storage: ref.watch(storageDioProvider),
    ));
