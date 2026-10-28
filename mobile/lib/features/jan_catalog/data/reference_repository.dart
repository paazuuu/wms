import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';

/// 参照資料 (0160): a catalog the JANs were read from, or a site a person
/// added, with every copy kept of it.
class ReferenceSource extends Equatable {
  const ReferenceSource({
    required this.id,
    required this.kind,
    required this.url,
    this.janCatalogId,
    this.title,
    this.maker,
    this.note,
    this.lastCheckedAt,
    this.snapshots = const [],
  });

  final int id;

  /// catalog or site.
  final String kind;
  final String url;
  final int? janCatalogId;
  final String? title;
  final String? maker;
  final String? note;
  final DateTime? lastCheckedAt;

  /// Newest first.
  final List<ReferenceSnapshot> snapshots;

  bool get isSite => kind == 'site';

  factory ReferenceSource.fromJson(Map<String, dynamic> j) => ReferenceSource(
        id: (j['id'] as num).toInt(),
        kind: j['kind']?.toString() ?? 'site',
        url: j['url']?.toString() ?? '',
        janCatalogId: (j['jan_catalog_id'] as num?)?.toInt(),
        title: j['title'] as String?,
        maker: j['maker'] as String?,
        note: j['note'] as String?,
        lastCheckedAt: _date(j['last_checked_at']),
        snapshots: [
          for (final s in (j['reference_snapshots'] as List? ?? const []).whereType<Map>())
            ReferenceSnapshot.fromJson(s.cast<String, dynamic>()),
        ]..sort((a, b) => b.takenAt.compareTo(a.takenAt)),
      );

  @override
  List<Object?> get props => [id, kind, url, janCatalogId, title, maker, note, lastCheckedAt, snapshots];
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// One file of a copy: entries (the JANs as read), text, html, pdf or file.
class ReferenceFile extends Equatable {
  const ReferenceFile({required this.kind, required this.path, this.bytes, this.type});

  final String kind;
  final String path;
  final int? bytes;
  final String? type;

  factory ReferenceFile.fromJson(Map<String, dynamic> j) => ReferenceFile(
        kind: j['kind']?.toString() ?? 'file',
        path: j['path']?.toString() ?? '',
        bytes: (j['bytes'] as num?)?.toInt(),
        type: j['type'] as String?,
      );

  @override
  List<Object?> get props => [kind, path, bytes, type];
}

/// A copy as it was when taken, in its 年度 (April to March).
class ReferenceSnapshot extends Equatable {
  const ReferenceSnapshot({
    required this.id,
    required this.takenAt,
    required this.fiscalYear,
    this.title,
    this.edition,
    this.pageCount,
    this.entryCount,
    this.weightCount,
    this.files = const [],
  });

  final int id;
  final DateTime takenAt;
  final int fiscalYear;
  final String? title;
  final String? edition;
  final int? pageCount;
  final int? entryCount;
  final int? weightCount;
  final List<ReferenceFile> files;

  ReferenceFile? file(String kind) => files.where((f) => f.kind == kind).firstOrNull;

  factory ReferenceSnapshot.fromJson(Map<String, dynamic> j) => ReferenceSnapshot(
        id: (j['id'] as num).toInt(),
        takenAt: _date(j['taken_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        fiscalYear: (j['fiscal_year'] as num?)?.toInt() ?? 0,
        title: j['title'] as String?,
        edition: j['edition'] as String?,
        pageCount: (j['page_count'] as num?)?.toInt(),
        entryCount: (j['entry_count'] as num?)?.toInt(),
        weightCount: (j['weight_count'] as num?)?.toInt(),
        files: [
          for (final f in (j['files'] as List? ?? const []).whereType<Map>())
            ReferenceFile.fromJson(f.cast<String, dynamic>()),
        ],
      );

  @override
  List<Object?> get props => [id, takenAt, fiscalYear, title, edition, pageCount, entryCount, weightCount, files];
}

/// 年度 of a moment (April to March, Japan time), as the database keeps it.
int fiscalYearOf(DateTime at) {
  final t = at.toUtc().add(const Duration(hours: 9));
  return t.month < 4 ? t.year - 1 : t.year;
}

abstract class ReferenceRepository {
  Future<ApiResult<List<ReferenceSource>>> list();

  /// A site added and saved now; a PDF is kept as a PDF, a page as its HTML
  /// and text.
  Future<ApiResult<void>> addSite({required String url, String? title, String? maker, String? note});

  /// A copy taken again now (kept only when something changed).
  Future<ApiResult<void>> saveAgain(int sourceId);
  Future<ApiResult<void>> delete(int sourceId);

  /// A kept file's bytes (to show a catalog's JAN list).
  Future<ApiResult<Uint8List>> fileBytes(String path);

  /// A link that opens a kept file for an hour.
  Future<ApiResult<String>> signedUrl(String path);
}

const referenceBucket = 'reference-archive';

class ReferenceRepositoryImpl implements ReferenceRepository {
  ReferenceRepositoryImpl(this._rest, this._functions, this._storage);

  final Dio _rest;
  final Dio _functions;
  final Dio _storage;

  @override
  Future<ApiResult<List<ReferenceSource>>> list() async {
    try {
      final r =
          await _rest.get('/reference_sources', queryParameters: {'select': '*,reference_snapshots(*)', 'order': 'id'});
      return ApiSuccess([
        for (final x in (r.data as List? ?? const []).whereType<Map>())
          ReferenceSource.fromJson(x.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<void>> addSite({required String url, String? title, String? maker, String? note}) async {
    try {
      await _functions.post('/jan-catalog/reference',
          data: {
            'url': url,
            if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
            if (maker != null && maker.trim().isNotEmpty) 'maker': maker.trim(),
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          },
          options: Options(receiveTimeout: const Duration(minutes: 2)));
      return const ApiSuccess(null);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<void>> saveAgain(int sourceId) async {
    try {
      await _functions.post('/jan-catalog/reference/$sourceId/save',
          options: Options(receiveTimeout: const Duration(minutes: 2)));
      return const ApiSuccess(null);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<void>> delete(int sourceId) async {
    try {
      await _functions.delete('/jan-catalog/reference/$sourceId');
      return const ApiSuccess(null);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(String path) async {
    try {
      final r = await _storage.get<List<int>>('/object/authenticated/$referenceBucket/$path',
          options: Options(responseType: ResponseType.bytes));
      return ApiSuccess(Uint8List.fromList(r.data ?? const []));
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<String>> signedUrl(String path) async {
    try {
      final r = await _storage.post('/object/sign/$referenceBucket/$path', data: {'expiresIn': 3600});
      final signed = (r.data as Map)['signedURL'] as String? ?? '';
      return ApiSuccess('${_storage.options.baseUrl}$signed');
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }
}

final referenceRepositoryProvider = Provider<ReferenceRepository>((ref) => ReferenceRepositoryImpl(
      ref.watch(restDioProvider),
      ref.watch(deliveryDioProvider),
      ref.watch(storageDioProvider),
    ));

final referenceSourcesProvider = FutureProvider.autoDispose<List<ReferenceSource>>((ref) async {
  final r = await ref.watch(referenceRepositoryProvider).list();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// A catalog copy's JAN list (entries.json) as a table: headers and rows.
({List<String> headers, List<List<Object?>> rows, Map<String, dynamic> catalog}) entriesTable(
    Map<String, dynamic> json) {
  final rows = <List<Object?>>[
    for (final r in (json['rows'] as List? ?? const []).whereType<List>())
      [
        r.isNotEmpty ? r[0] : null, // jan
        r.length > 1 ? r[1] : null, // code_hint
        r.length > 2 ? r[2] : null, // weight_g
        r.length > 3 ? r[3] : null, // weight_text
        r.length > 4 ? r[4] : null, // weight_basis
        r.length > 5 ? r[5] : null, // page
        r.length > 6 ? r[6] : null, // line_text
      ],
  ];
  return (
    headers: const ['JANコード', '品番など（記載）', '重量 g（1単位）', '重量の記載', '重量の基準', 'ページ', '前後の記載'],
    rows: rows,
    catalog: (json['catalog'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
}
