import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart' show mimeTypeFor;
import '../../delivery/application/delivery_providers.dart';

/// Where 仕入先回答's files are kept (0218): <answer id>/<file>.
const supplierAnswerBucket = 'supplier-answers';

class SupplierAnswerFile extends Equatable {
  const SupplierAnswerFile({required this.id, required this.name, required this.path, this.contentType, this.size});

  final int id;
  final String name;
  final String path;
  final String? contentType;
  final int? size;

  factory SupplierAnswerFile.fromJson(Map<String, dynamic> j) => SupplierAnswerFile(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: '${j['file_name'] ?? ''}',
        path: '${j['storage_path'] ?? ''}',
        contentType: j['content_type']?.toString(),
        size: (j['byte_size'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props => [id, name, path];
}

/// 仕入先回答 (0218): what a supplier answered — what it can supply, how many,
/// by when — kept as its files with a memo, by supplier and, when it
/// answers one, by 入荷希望リスト.
class SupplierAnswer extends Equatable {
  const SupplierAnswer({
    required this.id,
    this.supplierId,
    this.supplierName = '',
    this.requestId,
    this.requestNumber,
    this.requestLabel,
    this.answeredOn,
    this.title,
    this.note,
    this.createdByName,
    this.files = const [],
  });

  final int id;
  final int? supplierId;
  final String supplierName;
  final int? requestId;
  final String? requestNumber;
  final String? requestLabel;
  final DateTime? answeredOn;
  final String? title;
  final String? note;
  final String? createdByName;
  final List<SupplierAnswerFile> files;

  factory SupplierAnswer.fromJson(Map<String, dynamic> j) => SupplierAnswer(
        id: (j['id'] as num?)?.toInt() ?? 0,
        supplierId: (j['supplier_id'] as num?)?.toInt(),
        supplierName: '${j['supplier_name'] ?? ''}',
        requestId: (j['request_id'] as num?)?.toInt(),
        requestNumber: j['request_number']?.toString(),
        requestLabel: j['request_label']?.toString(),
        answeredOn: DateTime.tryParse('${j['answered_on'] ?? ''}'),
        title: j['title']?.toString(),
        note: j['note']?.toString(),
        createdByName: j['created_by_name']?.toString(),
        files: [
          for (final f in (j['files'] as List? ?? const []).whereType<Map>())
            SupplierAnswerFile.fromJson(f.cast<String, dynamic>()),
        ],
      );

  @override
  List<Object?> get props =>
      [id, supplierId, supplierName, requestId, requestNumber, requestLabel, answeredOn, title, note, files];
}

/// What is saved for one answer.
class SupplierAnswerDraft {
  const SupplierAnswerDraft({
    this.id,
    required this.supplierName,
    this.supplierId,
    this.requestId,
    this.answeredOn,
    this.title,
    this.note,
  });

  final int? id;
  final String supplierName;
  final int? supplierId;
  final int? requestId;
  final DateTime? answeredOn;
  final String? title;
  final String? note;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'supplier_name': supplierName,
        if (supplierId != null) 'supplier_id': supplierId,
        if (requestId != null) 'request_id': requestId,
        if (answeredOn != null)
          'answered_on':
              '${answeredOn!.year}-${answeredOn!.month.toString().padLeft(2, '0')}-${answeredOn!.day.toString().padLeft(2, '0')}',
        if ((title ?? '').trim().isNotEmpty) 'title': title!.trim(),
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
      };
}

abstract class SupplierAnswerRepository {
  Future<ApiResult<List<SupplierAnswer>>> list();

  /// A new answer ([SupplierAnswerDraft.id] null) or one changed; its id.
  Future<ApiResult<int>> save(SupplierAnswerDraft d);
  Future<ApiResult<bool>> remove(int id);

  /// A file put with answer [answerId].
  Future<ApiResult<int>> addFile(int answerId, String fileName, Uint8List bytes);
  Future<ApiResult<bool>> removeFile(int fileId);
  Future<ApiResult<Uint8List>> fileBytes(String path);
}

class SupplierAnswerRepositoryImpl implements SupplierAnswerRepository {
  SupplierAnswerRepositoryImpl(this._rest, this._storage);

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

  @override
  Future<ApiResult<List<SupplierAnswer>>> list() => _rpc('supplier_answers_list', const {}, (d) => [
        for (final r in (d is List ? d : const []).whereType<Map>()) SupplierAnswer.fromJson(r.cast<String, dynamic>()),
      ]);

  @override
  Future<ApiResult<int>> save(SupplierAnswerDraft d) =>
      _rpc('supplier_answer_save', {'p': d.toJson()}, (v) => (v as num).toInt());

  @override
  Future<ApiResult<bool>> remove(int id) => _rpc('supplier_answer_remove', {'p_id': id}, (d) => d == true);

  @override
  Future<ApiResult<int>> addFile(int answerId, String fileName, Uint8List bytes) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path = '$answerId/${DateTime.now().millisecondsSinceEpoch}-$safe';
    final type = mimeTypeFor(fileName);
    try {
      await _storage.post('/object/$supplierAnswerBucket/$path',
          data: bytes, options: Options(headers: {'Content-Type': type}));
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
    return _rpc('supplier_answer_file_add',
        {'p_answer_id': answerId, 'p_path': path, 'p_name': fileName, 'p_type': type, 'p_size': bytes.length},
        (d) => (d as num).toInt());
  }

  @override
  Future<ApiResult<bool>> removeFile(int fileId) =>
      _rpc('supplier_answer_file_remove', {'p_id': fileId}, (d) => d == true);

  @override
  Future<ApiResult<Uint8List>> fileBytes(String path) async {
    try {
      final r = await _storage.get<List<int>>('/object/authenticated/$supplierAnswerBucket/$path',
          options: Options(responseType: ResponseType.bytes));
      return ApiSuccess(Uint8List.fromList(r.data ?? const []));
    } on DioException catch (e) {
      return mapDioError<Uint8List>(e);
    }
  }
}

final supplierAnswerRepositoryProvider = Provider<SupplierAnswerRepository>(
    (ref) => SupplierAnswerRepositoryImpl(ref.watch(restDioProvider), ref.watch(storageDioProvider)));

final supplierAnswersProvider = FutureProvider.autoDispose<List<SupplierAnswer>>((ref) async =>
    (await ref.watch(supplierAnswerRepositoryProvider).list())
        .when(success: (d) => d, failure: (f) => throw Exception(f.message)));
