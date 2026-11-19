import 'dart:typed_data';

import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/purchase_request/data/supplier_answer_repository.dart';

/// 仕入先回答 (0218) without a server: kept in memory, files and all.
class FakeSupplierAnswerRepository implements SupplierAnswerRepository {
  FakeSupplierAnswerRepository([List<SupplierAnswer> answers = const []]) : answers = [...answers];

  final List<SupplierAnswer> answers;
  final saved = <SupplierAnswerDraft>[];
  final bytes = <String, Uint8List>{};
  var _id = 100, _fileId = 500;

  @override
  Future<ApiResult<List<SupplierAnswer>>> list() async => ApiSuccess([...answers]);

  @override
  Future<ApiResult<int>> save(SupplierAnswerDraft d) async {
    saved.add(d);
    final id = d.id ?? ++_id;
    final old = answers.where((a) => a.id == id).firstOrNull;
    answers
      ..removeWhere((a) => a.id == id)
      ..insert(
          0,
          SupplierAnswer(
            id: id,
            supplierName: d.supplierName,
            requestId: d.requestId,
            answeredOn: d.answeredOn,
            title: d.title,
            note: d.note,
            files: old?.files ?? const [],
          ));
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<bool>> remove(int id) async {
    answers.removeWhere((a) => a.id == id);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<int>> addFile(int answerId, String fileName, Uint8List data) async {
    final i = answers.indexWhere((a) => a.id == answerId);
    final f = SupplierAnswerFile(id: ++_fileId, name: fileName, path: '$answerId/$fileName');
    bytes[f.path] = data;
    final a = answers[i];
    answers[i] = SupplierAnswer(
      id: a.id,
      supplierName: a.supplierName,
      requestId: a.requestId,
      answeredOn: a.answeredOn,
      title: a.title,
      note: a.note,
      files: [...a.files, f],
    );
    return ApiSuccess(f.id);
  }

  @override
  Future<ApiResult<bool>> removeFile(int fileId) async => const ApiSuccess(true);

  @override
  Future<ApiResult<Uint8List>> fileBytes(String path) async => ApiSuccess(bytes[path] ?? Uint8List(0));
}
