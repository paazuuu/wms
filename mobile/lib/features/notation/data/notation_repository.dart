import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/notation.dart';

/// Pre-training the dialect dictionary (0105/0106): read a company's sample
/// file without booking anything, check it, teach what it showed; and look
/// after the dictionary and the column headings it has learned.
abstract class NotationRepository {
  /// Reads [file] as [partnerId]'s document (Excel, CSV, PDF or photo) and
  /// records the run. [overrides] corrects what a column holds (index → field).
  Future<ApiResult<TrainingRead>> readSample({
    required int partnerId,
    required MultipartFile file,
    Map<int, ColumnField> overrides = const {},
  });

  /// Teaches what a checked reading showed.
  Future<ApiResult<LearnResult>> learn({
    required int partnerId,
    int? trainingId,
    required List<ReadLineResult> lines,
    required List<ReadColumn> columns,
  });

  Future<ApiResult<List<TrainingRun>>> trainings({int? partnerId});
  Future<ApiResult<List<PartnerTrainingStats>>> stats();
  Future<ApiResult<bool>> discard(int trainingId);

  Future<ApiResult<List<NotationDialect>>> dialects({
    int? partnerId,
    String? field,
    String? search,
    bool unconfirmedOnly = false,
  });
  Future<ApiResult<bool>> confirmDialect(int id, {int? productId, int? makerId, bool confirmed = true});
  Future<ApiResult<bool>> removeDialect(int id);

  Future<ApiResult<List<ColumnAlias>>> columnAliases({int? partnerId});
  Future<ApiResult<bool>> setColumnAlias({int? partnerId, required String header, required ColumnField field});
  Future<ApiResult<bool>> removeColumnAlias(int id);

  /// The company's dictionary versions, newest first (0108).
  Future<ApiResult<List<LibraryVersion>>> libraryVersions(int partnerId);
  Future<ApiResult<int>> snapshotLibrary(int partnerId, {String? note});
  Future<ApiResult<LibraryRestoreResult>> restoreLibrary(int versionId);
}

List<Map<String, dynamic>> _list(dynamic data) {
  final raw = data is List && data.length == 1 && data.first is List ? data.first : data;
  return [for (final e in (raw as List? ?? const []).whereType<Map>()) e.cast<String, dynamic>()];
}

class NotationRepositoryImpl implements NotationRepository {
  NotationRepositoryImpl(this._functions, this._rest);

  /// Edge functions (import-plan).
  final Dio _functions;

  /// PostgREST RPCs.
  final Dio _rest;

  @override
  Future<ApiResult<TrainingRead>> readSample({
    required int partnerId,
    required MultipartFile file,
    Map<int, ColumnField> overrides = const {},
  }) async {
    try {
      final form = FormData.fromMap({
        'file': file,
        'mode': 'training',
        'partner_id': '$partnerId',
        if (overrides.isNotEmpty)
          'column_overrides': jsonEncode({for (final e in overrides.entries) '${e.key}': e.value.wire}),
      });
      final r = await _functions.post('/import-plan', data: form);
      final body = (r.data as Map).cast<String, dynamic>();
      return ApiSuccess(TrainingRead.fromJson((body['data'] as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<TrainingRead>(e);
    }
  }

  @override
  Future<ApiResult<LearnResult>> learn({
    required int partnerId,
    int? trainingId,
    required List<ReadLineResult> lines,
    required List<ReadColumn> columns,
  }) async {
    try {
      final r = await _functions.post('/import-plan', data: {
        'mode': 'learn',
        'partner_id': partnerId,
        'training_id': trainingId,
        'lines': [for (final l in lines) if (l.product != null) l.toLearnJson()],
        'columns': [
          for (final c in columns)
            if (c.field != null && c.header.isNotEmpty) {'header': c.header, 'field': c.field!.wire},
        ],
      });
      final body = (r.data as Map).cast<String, dynamic>();
      return ApiSuccess(LearnResult.fromJson((body['data'] as Map? ?? const {}).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<LearnResult>(e);
    }
  }

  @override
  Future<ApiResult<List<TrainingRun>>> trainings({int? partnerId}) async {
    try {
      final r = await _rest.post('/rpc/list_notation_trainings', data: {'p_partner_id': partnerId});
      return ApiSuccess([for (final m in _list(r.data)) TrainingRun.fromJson(m)]);
    } on DioException catch (e) {
      return mapDioError<List<TrainingRun>>(e);
    }
  }

  @override
  Future<ApiResult<List<PartnerTrainingStats>>> stats() async {
    try {
      final r = await _rest.post('/rpc/notation_training_stats', data: const {});
      return ApiSuccess([for (final m in _list(r.data)) PartnerTrainingStats.fromJson(m)]);
    } on DioException catch (e) {
      return mapDioError<List<PartnerTrainingStats>>(e);
    }
  }

  @override
  Future<ApiResult<bool>> discard(int trainingId) async {
    try {
      await _rest.post('/rpc/discard_notation_training', data: {'p_id': trainingId});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<List<NotationDialect>>> dialects({
    int? partnerId,
    String? field,
    String? search,
    bool unconfirmedOnly = false,
  }) async {
    try {
      final r = await _rest.post('/rpc/list_notation_dialects', data: {
        'p_partner_id': partnerId,
        'p_field': field,
        'p_search': (search == null || search.trim().isEmpty) ? null : search.trim(),
        'p_unconfirmed_only': unconfirmedOnly,
      });
      return ApiSuccess([for (final m in _list(r.data)) NotationDialect.fromJson(m)]);
    } on DioException catch (e) {
      return mapDioError<List<NotationDialect>>(e);
    }
  }

  @override
  Future<ApiResult<bool>> confirmDialect(int id, {int? productId, int? makerId, bool confirmed = true}) async {
    try {
      await _rest.post('/rpc/set_notation_dialect', data: {
        'p_id': id,
        'p_product_id': productId,
        'p_maker_id': makerId,
        'p_confirmed': confirmed,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> removeDialect(int id) async {
    try {
      await _rest.post('/rpc/remove_notation_dialect', data: {'p_id': id});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<List<ColumnAlias>>> columnAliases({int? partnerId}) async {
    try {
      final r = await _rest.post('/rpc/list_column_aliases', data: {'p_partner_id': partnerId});
      return ApiSuccess([for (final m in _list(r.data)) ColumnAlias.fromJson(m)]);
    } on DioException catch (e) {
      return mapDioError<List<ColumnAlias>>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setColumnAlias({int? partnerId, required String header, required ColumnField field}) async {
    try {
      await _rest.post('/rpc/set_column_alias', data: {
        'p_partner_id': partnerId,
        'p_header': header,
        'p_field': field.wire,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> removeColumnAlias(int id) async {
    try {
      await _rest.post('/rpc/remove_column_alias', data: {'p_id': id});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<List<LibraryVersion>>> libraryVersions(int partnerId) async {
    try {
      final r = await _rest.post('/rpc/list_notation_library_versions', data: {'p_partner_id': partnerId});
      return ApiSuccess([for (final m in _list(r.data)) LibraryVersion.fromJson(m)]);
    } on DioException catch (e) {
      return mapDioError<List<LibraryVersion>>(e);
    }
  }

  @override
  Future<ApiResult<int>> snapshotLibrary(int partnerId, {String? note}) async {
    try {
      final r = await _rest.post('/rpc/snapshot_notation_library', data: {'p_partner_id': partnerId, 'p_note': note});
      final d = r.data is List && (r.data as List).isNotEmpty ? (r.data as List).first : r.data;
      return ApiSuccess(d is int ? d : int.tryParse('$d') ?? 0);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<LibraryRestoreResult>> restoreLibrary(int versionId) async {
    try {
      final r = await _rest.post('/rpc/restore_notation_library_version', data: {'p_id': versionId});
      final d = r.data is List && (r.data as List).isNotEmpty ? (r.data as List).first : r.data;
      return ApiSuccess(LibraryRestoreResult.fromJson((d as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<LibraryRestoreResult>(e);
    }
  }
}
