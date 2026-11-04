import 'dart:typed_data';

import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/packing/data/packing_repository.dart';
import 'package:wms_mobile/features/packing/domain/packing.dart';
import 'package:wms_mobile/features/packing/domain/packing_list_reader.dart';

/// 梱包 (0192) in memory: boxes saved get ids, updates are written to them,
/// uploads are kept by path so they can be read back.
class FakePackingRepository implements PackingRepository {
  FakePackingRepository({this.cases = const [], this.ai = const {}, List<PackingListRecord>? lists})
      : records = lists ?? [];

  List<CasePack> cases;
  Map<int, PlField> ai;
  final List<PackingListRecord> records;
  final Map<int, List<PackBox>> saved = {};
  final List<(int, Map<String, dynamic>)> updates = [];
  final Map<String, Uint8List> files = {};
  final List<List<String>> asked = [];
  final List<(List<CasePack>, String)> casesSaved = [];
  final List<int> withdrawn = [];
  var _id = 100;

  @override
  Future<ApiResult<List<CasePack>>> casePacks() async => ApiSuccess(cases);

  @override
  Future<ApiResult<int>> saveCasePacks(List<CasePack> rows, {String source = 'manual'}) async {
    casesSaved.add((rows, source));
    return ApiSuccess(rows.length);
  }

  @override
  Future<ApiResult<bool>> retireCasePack(int productId) async => const ApiSuccess(true);

  @override
  Future<ApiResult<List<PackBox>>> boxes(int fileId) async => ApiSuccess(saved[fileId] ?? const []);

  @override
  Future<ApiResult<int>> saveBoxes(int fileId, List<PackBox> boxes) async {
    saved[fileId] = [
      for (final b in boxes)
        PackBox(
          id: ++_id,
          boxNo: b.boxNo,
          mark: b.mark,
          cartonTypeId: b.cartonTypeId,
          cartonType: b.cartonType,
          ownCase: b.ownCase,
          lengthCm: b.lengthCm,
          widthCm: b.widthCm,
          heightCm: b.heightCm,
          tareKg: b.tareKg,
          estKg: b.estKg,
          grossKg: b.grossKg,
          items: [
            for (final i in b.items)
              PackItem(
                id: ++_id,
                fileLineId: i.fileLineId,
                productId: i.productId,
                jan: i.jan,
                code: i.code,
                name: i.name,
                maker: i.maker,
                quantity: i.quantity,
                unitWeightG: i.unitWeightG,
              ),
          ],
        ),
    ];
    return ApiSuccess(boxes.length);
  }

  @override
  Future<ApiResult<bool>> updateBox(int id, Map<String, dynamic> fields) async {
    updates.add((id, fields));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<int>> addList({
    required int warehouseId,
    required String source,
    int? fileId,
    String? originalName,
    String? originalPath,
    String? improvedName,
    String? improvedPath,
    int? boxes,
    int? quantity,
    double? grossKg,
    double? cbm,
    String? note,
  }) async {
    final id = ++_id;
    records.insert(
        0,
        PackingListRecord(
          id: id,
          warehouseId: warehouseId,
          source: source,
          fileId: fileId,
          originalName: originalName,
          originalPath: originalPath,
          improvedName: improvedName,
          improvedPath: improvedPath,
          boxes: boxes,
          quantity: quantity,
          grossKg: grossKg,
          cbm: cbm,
          note: note,
        ));
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<List<PackingListRecord>>> lists({int? fileId}) async =>
      ApiSuccess([for (final r in records) if (fileId == null || r.fileId == fileId) r]);

  @override
  Future<ApiResult<bool>> withdrawList(int id) async {
    withdrawn.add(id);
    records.removeWhere((r) => r.id == id);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<String>> upload(int warehouseId, String fileName, Uint8List bytes) async {
    final path = '$warehouseId/pl/${files.length + 1}-$fileName';
    files[path] = bytes;
    return ApiSuccess(path);
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(String path) async =>
      files[path] == null ? const ApiFailure(message: 'not found') : ApiSuccess(files[path]!);

  @override
  Future<ApiResult<Map<int, PlField>>> aiColumns(List<String> headers, List<List<String>> samples) async {
    asked.add(headers);
    return ApiSuccess(ai);
  }
}
