import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../domain/master_import.dart';

/// Where an import's files are kept (0138).
const masterImportBucket = 'master-import-files';

/// One file through 商品マスタ and then stock (0138).
abstract class MasterImportRepository {
  /// Reads [bytes] with import-plan (nothing booked); the file is kept as
  /// evidence there too.
  Future<ApiResult<MasterRead>> read(String fileName, Uint8List bytes);

  /// Opens an import for a chosen file.
  Future<ApiResult<int>> start({required String fileName, String? contentType, String? source, int? documentId, int? supplierId});

  /// Keeps a file with the import: original, converted or corrected.
  Future<ApiResult<String>> keepFile(int importId, String kind, String fileName, Uint8List bytes, String contentType);

  /// Records why the import stopped; nothing is written.
  Future<ApiResult<bool>> stop(int importId, List<MasterProblem> problems, int lineCount);

  Future<ApiResult<bool>> cancel(int importId);

  /// Stage 1. A file with any problem comes back with ok = false, untouched.
  Future<ApiResult<MasterCommitResult>> commit(int importId, List<MasterLine> lines, {int? supplierId});

  /// The import with its lines; with [warehouseId], each line's stock there.
  Future<ApiResult<MasterImport>> detail(int importId, {int? warehouseId});

  /// Stage 2: [lines] is {line_no, quantity?, on_hand_set?} per changed line.
  Future<ApiResult<int>> applyStock(int importId, int warehouseId, List<Map<String, dynamic>> lines);

  Future<ApiResult<List<MasterImport>>> list();

  Future<ApiResult<Uint8List>> download(String path);

  /// What one JAN has in a warehouse now (0 when nothing).
  Future<ApiResult<int>> onHand(int warehouseId, String janCode);

  /// One product's stock set to [quantity] by hand.
  Future<ApiResult<({int before, int after})>> setOnHand(int warehouseId, String janCode, int quantity, {String? note});
}

class MasterImportRepositoryImpl implements MasterImportRepository {
  MasterImportRepositoryImpl({required Dio rest, required Dio functions, required Dio storage})
      : _rest = rest,
        _functions = functions,
        _storage = storage;

  final Dio _rest;
  final Dio _functions;
  final Dio _storage;

  static Object? _one(Object? d) => d is List && d.isNotEmpty ? d.first : d;

  Future<ApiResult<T>> _rpc<T>(String name, Map<String, dynamic> body, T Function(Object? data) read) async {
    try {
      final r = await _rest.post('/rpc/$name', data: body);
      return ApiSuccess(read(r.data));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  @override
  Future<ApiResult<MasterRead>> read(String fileName, Uint8List bytes) async {
    try {
      final form = FormData()
        ..files.add(MapEntry('file', MultipartFile.fromBytes(bytes, filename: fileName)))
        ..fields.addAll(const [MapEntry('dry_run', '1'), MapEntry('purpose', 'library')]);
      final r = await _functions.post('/import-plan',
          data: form, options: Options(receiveTimeout: const Duration(seconds: 180)));
      return ApiSuccess(MasterRead.fromJson(((r.data as Map)['data'] as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<MasterRead>(e);
    }
  }

  @override
  Future<ApiResult<int>> start({
    required String fileName,
    String? contentType,
    String? source,
    int? documentId,
    int? supplierId,
  }) =>
      _rpc('master_import_start', {
        'p_original_name': fileName,
        'p_original_type': contentType,
        'p_source': source,
        'p_document_id': documentId,
        'p_supplier_id': supplierId,
      }, (d) => (d as num).toInt());

  @override
  Future<ApiResult<String>> keepFile(int importId, String kind, String fileName, Uint8List bytes, String contentType) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path = 'imports/$importId/$kind-${DateTime.now().millisecondsSinceEpoch}-$safe';
    try {
      await _storage.post('/object/$masterImportBucket/$path',
          data: bytes, options: Options(headers: {'Content-Type': contentType}));
    } on DioException catch (e) {
      return mapDioError<String>(e);
    }
    final r = await _rpc('master_import_attach', {'p_id': importId, 'p_kind': kind, 'p_name': fileName, 'p_path': path},
        (_) => path);
    return r;
  }

  @override
  Future<ApiResult<bool>> stop(int importId, List<MasterProblem> problems, int lineCount) => _rpc('master_import_stop', {
        'p_id': importId,
        'p_issues': [for (final p in problems) p.toJson()],
        'p_line_count': lineCount,
      }, (d) => d == true);

  @override
  Future<ApiResult<bool>> cancel(int importId) => _rpc('master_import_cancel', {'p_id': importId}, (d) => d == true);

  @override
  Future<ApiResult<MasterCommitResult>> commit(int importId, List<MasterLine> lines, {int? supplierId}) =>
      _rpc('master_import_commit', {
        'p_id': importId,
        'p_lines': [for (final l in lines) l.toJson()],
        'p_supplier_id': supplierId,
      }, (d) => MasterCommitResult.fromJson((_one(d) as Map).cast<String, dynamic>()));

  @override
  Future<ApiResult<MasterImport>> detail(int importId, {int? warehouseId}) =>
      _rpc('master_import_detail', {'p_id': importId, 'p_warehouse_id': warehouseId},
          (d) => MasterImport.fromJson((_one(d) as Map).cast<String, dynamic>()));

  @override
  Future<ApiResult<int>> applyStock(int importId, int warehouseId, List<Map<String, dynamic>> lines) =>
      _rpc('master_import_apply_stock', {'p_id': importId, 'p_warehouse_id': warehouseId, 'p_lines': lines},
          (d) => ((_one(d) as Map)['added'] as num?)?.toInt() ?? 0);

  @override
  Future<ApiResult<List<MasterImport>>> list() => _rpc('master_imports_list', const {'p_limit': 100}, (d) => [
        for (final e in (d is List ? d : const []).whereType<Map>()) MasterImport.fromJson(e.cast<String, dynamic>()),
      ]);

  @override
  Future<ApiResult<Uint8List>> download(String path) async {
    try {
      final r = await _storage.get<List<int>>('/object/authenticated/$masterImportBucket/$path',
          options: Options(responseType: ResponseType.bytes));
      return ApiSuccess(Uint8List.fromList(r.data ?? const []));
    } on DioException catch (e) {
      return mapDioError<Uint8List>(e);
    }
  }

  @override
  Future<ApiResult<int>> onHand(int warehouseId, String janCode) async {
    try {
      final r = await _rest.get('/stock_levels', queryParameters: {
        'select': 'on_hand',
        'warehouse_id': 'eq.$warehouseId',
        'jan_code': 'eq.$janCode',
      });
      final row = _one(r.data);
      return ApiSuccess(row is Map ? (row['on_hand'] as num?)?.toInt() ?? 0 : 0);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<({int before, int after})>> setOnHand(int warehouseId, String janCode, int quantity, {String? note}) =>
      _rpc('stock_set_on_hand', {
        'p_warehouse_id': warehouseId,
        'p_jan_code': janCode,
        'p_quantity': quantity,
        'p_note': note,
      }, (d) {
        final m = (_one(d) as Map);
        return (before: (m['before'] as num?)?.toInt() ?? 0, after: (m['after'] as num?)?.toInt() ?? quantity);
      });
}

final masterImportRepositoryProvider = Provider<MasterImportRepository>((ref) => MasterImportRepositoryImpl(
      rest: ref.watch(restDioProvider),
      functions: ref.watch(deliveryDioProvider),
      storage: ref.watch(storageDioProvider),
    ));

final masterImportsProvider = FutureProvider.autoDispose<List<MasterImport>>((ref) async {
  final r = await ref.watch(masterImportRepositoryProvider).list();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// One JAN's stock in one warehouse, for the hand correction on a product.
final productOnHandProvider = FutureProvider.autoDispose.family<int, (int, String)>((ref, key) async {
  final r = await ref.watch(masterImportRepositoryProvider).onHand(key.$1, key.$2);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
