import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart' show mimeTypeFor;
import '../../delivery/application/delivery_providers.dart';
import '../domain/overseas_stock.dart';

/// Where the sites' files are kept (0207).
const overseasFileBucket = 'overseas-files';

/// 国外の仮想在庫 (0207): sites abroad and the stock they say they hold.
abstract class OverseasStockRepository {
  Future<ApiResult<List<OverseasSite>>> sites({bool includeArchived = false});
  Future<ApiResult<int>> saveSite(Map<String, dynamic> site);
  Future<ApiResult<bool>> archiveSite(int id, bool archived);

  /// A file read for [siteId] as of [asOf]; its rows.
  Future<ApiResult<int>> import({
    required int siteId,
    required DateTime asOf,
    required List<OverseasLine> lines,
    String readBy = 'sheet',
    String? fileName,
    String? storagePath,
    int? fileSize,
    String? fingerprint,
    String? sheetName,
    Map<String, String>? columns,
    String? note,
  });
  Future<ApiResult<List<OverseasImport>>> imports(int siteId);
  Future<ApiResult<bool>> undo(int importId);

  /// An import's rows; with [importId] null, [siteId]'s stock now.
  Future<ApiResult<OverseasStock>> lines({int? importId, int? siteId});
  Future<ApiResult<List<OverseasProduct>>> overview({String? query});

  Future<ApiResult<String>> upload(int siteId, String fileName, Uint8List bytes);
  Future<ApiResult<Uint8List>> fileBytes(String storagePath);
}

class OverseasStockRepositoryImpl implements OverseasStockRepository {
  OverseasStockRepositoryImpl(this._rest, this._storage);

  final Dio _rest;
  final Dio _storage;

  Future<ApiResult<T>> _rpc<T>(String name, Map<String, dynamic> body, T Function(Object? data) read) async {
    try {
      final r = await _rest.post('/rpc/$name', data: body);
      return ApiSuccess(read(r.data));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  static List<Map<String, dynamic>> _rows(Object? d) => [
        for (final e in (d is List ? d : const []).whereType<Map>()) e.cast<String, dynamic>(),
      ];

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<ApiResult<List<OverseasSite>>> sites({bool includeArchived = false}) => _rpc('overseas_sites_list',
      {'p_include_archived': includeArchived}, (d) => [for (final r in _rows(d)) OverseasSite.fromJson(r)]);

  @override
  Future<ApiResult<int>> saveSite(Map<String, dynamic> site) =>
      _rpc('overseas_site_save', {'p': site}, (d) => (d as num).toInt());

  @override
  Future<ApiResult<bool>> archiveSite(int id, bool archived) =>
      _rpc('overseas_site_archive', {'p_id': id, 'p_archived': archived}, (d) => d == true);

  @override
  Future<ApiResult<int>> import({
    required int siteId,
    required DateTime asOf,
    required List<OverseasLine> lines,
    String readBy = 'sheet',
    String? fileName,
    String? storagePath,
    int? fileSize,
    String? fingerprint,
    String? sheetName,
    Map<String, String>? columns,
    String? note,
  }) =>
      _rpc('overseas_stock_import', {
        'p': {
          'site_id': siteId,
          'as_of': _day(asOf),
          'read_by': readBy,
          'file_name': fileName,
          'storage_path': storagePath,
          'file_size': fileSize,
          'fingerprint': fingerprint,
          'sheet_name': sheetName,
          'columns': columns,
          'note': note,
          'lines': [for (final l in lines) l.toJson()],
        },
      }, (d) => (d as num).toInt());

  @override
  Future<ApiResult<List<OverseasImport>>> imports(int siteId) =>
      _rpc('overseas_stock_imports', {'p_site_id': siteId}, (d) => [for (final r in _rows(d)) OverseasImport.fromJson(r)]);

  @override
  Future<ApiResult<bool>> undo(int importId) => _rpc('overseas_stock_undo', {'p_import_id': importId}, (d) => d == true);

  @override
  Future<ApiResult<OverseasStock>> lines({int? importId, int? siteId}) => _rpc('overseas_stock_lines',
      {'p_import_id': importId, 'p_site_id': siteId}, (d) => OverseasStock.fromJson((d as Map).cast<String, dynamic>()));

  @override
  Future<ApiResult<List<OverseasProduct>>> overview({String? query}) => _rpc('overseas_stock_overview',
      {'p_q': query, 'p_limit': 1000}, (d) => [for (final r in _rows(d)) OverseasProduct.fromJson(r)]);

  @override
  Future<ApiResult<String>> upload(int siteId, String fileName, Uint8List bytes) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path = '$siteId/${DateTime.now().millisecondsSinceEpoch}-$safe';
    try {
      await _storage.post('/object/$overseasFileBucket/$path',
          data: bytes, options: Options(headers: {'Content-Type': mimeTypeFor(fileName)}));
      return ApiSuccess(path);
    } on DioException catch (e) {
      return mapDioError<String>(e);
    }
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(String storagePath) async {
    try {
      final r = await _storage.get<List<int>>('/object/authenticated/$overseasFileBucket/$storagePath',
          options: Options(responseType: ResponseType.bytes));
      return ApiSuccess(Uint8List.fromList(r.data ?? const []));
    } on DioException catch (e) {
      return mapDioError<Uint8List>(e);
    }
  }
}

final overseasStockRepositoryProvider = Provider<OverseasStockRepository>(
    (ref) => OverseasStockRepositoryImpl(ref.watch(restDioProvider), ref.watch(storageDioProvider)));

final overseasSitesProvider = FutureProvider.autoDispose.family<List<OverseasSite>, bool>((ref, archived) async {
  final r = await ref.watch(overseasStockRepositoryProvider).sites(includeArchived: archived);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

final overseasStockProvider = FutureProvider.autoDispose.family<OverseasStock, int>((ref, siteId) async {
  final r = await ref.watch(overseasStockRepositoryProvider).lines(siteId: siteId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

final overseasImportsProvider = FutureProvider.autoDispose.family<List<OverseasImport>, int>((ref, siteId) async {
  final r = await ref.watch(overseasStockRepositoryProvider).imports(siteId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

final overseasOverviewProvider = FutureProvider.autoDispose.family<List<OverseasProduct>, String>((ref, q) async {
  final r = await ref.watch(overseasStockRepositoryProvider).overview(query: q.trim().isEmpty ? null : q.trim());
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
