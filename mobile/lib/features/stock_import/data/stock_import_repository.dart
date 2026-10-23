import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../master_import/data/master_import_repository.dart' show masterImportBucket;
import '../domain/stock_file.dart';
import '../domain/stock_ledger.dart';

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

  /// Imports already in with the same file or the same lines (0147).
  Future<ApiResult<List<DuplicateImport>>> duplicates({String? file, String? lines});

  /// Notes the two fingerprints on an import, right after it.
  Future<ApiResult<bool>> fingerprint(int importId, {String? file, String? lines});

  /// Takes an import back: every line's change booked the other way.
  Future<ApiResult<int>> undo(int importId);

  /// Keeps [lines] for inspection in [warehouseId] (0148): nothing is
  /// booked until [inspect].
  Future<ApiResult<StockFileResult>> stage(int warehouseId, List<StockFileLine> lines, {String? fileName, String? fileType});

  /// Stock files waiting for inspection.
  Future<ApiResult<List<AwaitingImport>>> awaiting({int? warehouseId});

  /// The inspector's count of [lines] of [importId], booked into stock.
  Future<ApiResult<InspectionResult>> inspect(int importId, List<InspectedLine> lines);

  /// Units waiting for inspection, by warehouse and JAN.
  Future<ApiResult<PendingInspection>> pendingInspection({int? warehouseId});

  /// Notes the document's date, whether the supplier is paid, and a memo.
  /// Only what is given changes.
  Future<ApiResult<bool>> updateNotes(int importId, {DocumentDate? date, bool? paid, String? note});

  /// Stock files dated from [from] to [to], for the calendar.
  Future<ApiResult<List<CalendarImport>>> calendar(DateTime from, DateTime to);
}

/// An earlier import of the same file or the same lines.
class DuplicateImport {
  const DuplicateImport({
    required this.importId,
    required this.at,
    this.fileName,
    this.warehouseName,
    this.lines = 0,
    this.change = 0,
    this.sameFile = false,
  });

  final int importId;
  final DateTime at;
  final String? fileName;
  final String? warehouseName;
  final int lines;
  final int change;
  final bool sameFile;

  factory DuplicateImport.fromJson(Map<String, dynamic> j) => DuplicateImport(
        importId: (j['import_id'] as num?)?.toInt() ?? 0,
        at: DateTime.tryParse('${j['at'] ?? ''}')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
        fileName: j['file_name']?.toString(),
        warehouseName: j['warehouse_name']?.toString(),
        lines: (j['lines'] as num?)?.toInt() ?? 0,
        change: (j['change'] as num?)?.toInt() ?? 0,
        sameFile: j['same_file'] == true,
      );
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

  @override
  Future<ApiResult<List<DuplicateImport>>> duplicates({String? file, String? lines}) async {
    try {
      final r = await _rest.post('/rpc/stock_file_import_duplicates', data: {'p_file': file, 'p_lines': lines});
      final d = r.data is List && (r.data as List).isNotEmpty && (r.data as List).first is List ? (r.data as List).first : r.data;
      return ApiSuccess([for (final e in (d as List? ?? const []).whereType<Map>()) DuplicateImport.fromJson(e.cast())]);
    } on DioException catch (e) {
      return mapDioError<List<DuplicateImport>>(e);
    }
  }

  @override
  Future<ApiResult<bool>> fingerprint(int importId, {String? file, String? lines}) async {
    try {
      final r = await _rest.post('/rpc/stock_file_import_fingerprint', data: {'p_id': importId, 'p_file': file, 'p_lines': lines});
      return ApiSuccess(r.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<int>> undo(int importId) async {
    try {
      final r = await _rest.post('/rpc/stock_file_import_undo', data: {'p_id': importId});
      final d = r.data is List && (r.data as List).isNotEmpty ? (r.data as List).first : r.data;
      return ApiSuccess(((d as Map)['lines'] as num?)?.toInt() ?? 0);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }
  @override
  Future<ApiResult<StockFileResult>> stage(int warehouseId, List<StockFileLine> lines,
      {String? fileName, String? fileType}) async {
    try {
      final r = await _rest.post('/rpc/stock_file_stage', data: {
        'p_warehouse_id': warehouseId,
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

  List<Map> _rows(Object? data) {
    final d = data is List && data.isNotEmpty && data.first is List ? data.first : data;
    return (d as List? ?? const []).whereType<Map>().toList();
  }

  @override
  Future<ApiResult<List<AwaitingImport>>> awaiting({int? warehouseId}) async {
    try {
      final r = await _rest.post('/rpc/stock_file_awaiting', data: {'p_warehouse_id': warehouseId});
      return ApiSuccess([for (final e in _rows(r.data)) AwaitingImport.fromJson(e.cast())]);
    } on DioException catch (e) {
      return mapDioError<List<AwaitingImport>>(e);
    }
  }

  @override
  Future<ApiResult<InspectionResult>> inspect(int importId, List<InspectedLine> lines) async {
    try {
      final r = await _rest.post('/rpc/stock_file_inspect', data: {
        'p_id': importId,
        'p_lines': [for (final l in lines) l.toJson()],
      });
      final d = r.data is List && (r.data as List).isNotEmpty ? (r.data as List).first : r.data;
      return ApiSuccess(InspectionResult.fromJson((d as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<InspectionResult>(e);
    }
  }

  @override
  Future<ApiResult<PendingInspection>> pendingInspection({int? warehouseId}) async {
    try {
      final r = await _rest.post('/rpc/stock_pending_inspection', data: {'p_warehouse_id': warehouseId});
      return ApiSuccess(PendingInspection.fromRows(_rows(r.data)));
    } on DioException catch (e) {
      return mapDioError<PendingInspection>(e);
    }
  }

  @override
  Future<ApiResult<bool>> updateNotes(int importId, {DocumentDate? date, bool? paid, String? note}) async {
    try {
      await _rest.post('/rpc/stock_file_import_update', data: {
        'p_id': importId,
        'p_patch': {
          if (date != null) 'document_date': date.wire,
          if (date != null) 'document_date_source': date.source.wire,
          if (paid != null) 'paid': paid,
          if (note != null) 'note': note,
        },
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<List<CalendarImport>>> calendar(DateTime from, DateTime to) async {
    String day(DateTime d) => DocumentDate(d, DocumentDateSource.manual).wire;
    try {
      final r = await _rest.post('/rpc/stock_file_calendar', data: {'p_from': day(from), 'p_to': day(to)});
      return ApiSuccess([for (final e in _rows(r.data)) CalendarImport.fromJson(e.cast())]);
    } on DioException catch (e) {
      return mapDioError<List<CalendarImport>>(e);
    }
  }
}

final stockImportRepositoryProvider = Provider<StockImportRepository>((ref) => StockImportRepositoryImpl(
      rest: ref.watch(restDioProvider),
      storage: ref.watch(storageDioProvider),
    ));

/// Units waiting for inspection in every warehouse one may see (0148).
/// Empty when it cannot be read: the stock shown stays right either way.
final pendingInspectionProvider = FutureProvider.autoDispose<PendingInspection>((ref) async {
  final r = await ref.watch(stockImportRepositoryProvider).pendingInspection();
  return r is ApiSuccess<PendingInspection> ? r.data : const PendingInspection();
});

/// Stock files waiting for their inspection.
final awaitingImportsProvider = FutureProvider.autoDispose<List<AwaitingImport>>((ref) async {
  final r = await ref.watch(stockImportRepositoryProvider).awaiting();
  return switch (r) {
    ApiSuccess(:final data) => data,
    ApiFailure(:final message) => throw Exception(message),
  };
});
