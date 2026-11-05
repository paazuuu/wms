import 'dart:typed_data';

import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/outbound_file/data/outbound_file_repository.dart';

/// 出荷リストで出庫 (0188) in memory. [matcher] gives each row its product
/// (default: none); posting keeps the lines; [duplicateOnce] makes the first
/// post fail as outbound_duplicate.
class FakeOutboundFileRepository implements OutboundFileRepository {
  FakeOutboundFileRepository({
    this.matcher,
    this.files = const [],
    this.detailOf,
    this.duplicateOnce = false,
    this.bytes,
  });

  OutboundMatch Function(Map<String, String?> row)? matcher;
  List<OutboundFileSummary> files;
  OutboundFileDetail Function(int id)? detailOf;
  bool duplicateOnce;
  Uint8List? bytes;

  final List<List<Map<String, String?>>> matched = [];
  final List<({String path, String name, int size})> uploaded = [];
  final List<({List<OutboundPostLine> lines, bool allowDuplicate, String? path, DateTime shippedOn, String? sheet, bool proxy, String? principal, String fileName, bool plan})> posted = [];
  final List<int> undone = [];
  final List<(int, int?)> destinations = [];
  final List<(int, DateTime)> confirmed = [];
  final List<(int, DateTime)> rescheduled = [];
  final List<String> fetched = [];

  @override
  Future<ApiResult<List<OutboundMatch>>> match(List<Map<String, String?>> rows, int warehouseId) async {
    matched.add(rows);
    return ApiSuccess([for (final r in rows) matcher?.call(r) ?? OutboundMatch.none]);
  }

  @override
  Future<ApiResult<String>> upload(int warehouseId, String fileName, Uint8List bytes) async {
    final path = '$warehouseId/1-$fileName';
    uploaded.add((path: path, name: fileName, size: bytes.length));
    return ApiSuccess(path);
  }

  @override
  Future<ApiResult<int>> post({
    required int warehouseId,
    required DateTime shippedOn,
    required String fileName,
    required List<OutboundPostLine> lines,
    String? storagePath,
    int? byteSize,
    String? fingerprint,
    String? sheetName,
    String? destination,
    String? note,
    Map<String, String>? columns,
    bool allowDuplicate = false,
    bool proxy = false,
    String? principal,
    bool plan = false,
  }) async {
    if (duplicateOnce && !allowDuplicate) {
      duplicateOnce = false;
      return const ApiFailure(message: 'outbound_duplicate');
    }
    posted.add((lines: lines, allowDuplicate: allowDuplicate, path: storagePath, shippedOn: shippedOn, sheet: sheetName, proxy: proxy, principal: principal, fileName: fileName, plan: plan));
    return ApiSuccess(posted.length);
  }

  @override
  Future<ApiResult<List<OutboundFileSummary>>> list({required DateTime from, required DateTime to, int? warehouseId}) async =>
      ApiSuccess([for (final f in files) if (!f.shippedOn.isBefore(from) && !f.shippedOn.isAfter(to)) f]);

  @override
  Future<ApiResult<OutboundFileDetail>> detail(int id) async {
    final d = detailOf?.call(id);
    if (d != null) return ApiSuccess(d);
    final f = files.where((f) => f.id == id).firstOrNull ??
        OutboundFileSummary(id: id, warehouseId: 1, shippedOn: DateTime(2026, 11, 3), fileName: 'list.xlsx');
    return ApiSuccess(OutboundFileDetail(file: f, lines: const []));
  }

  @override
  Future<ApiResult<int>> undo(int id) async {
    undone.add(id);
    return const ApiSuccess(5);
  }

  @override
  Future<ApiResult<int>> confirm(int id, DateTime day) async {
    confirmed.add((id, day));
    return const ApiSuccess(7);
  }

  @override
  Future<ApiResult<bool>> reschedule(int id, DateTime day) async {
    rescheduled.add((id, day));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> setDestination(int fileId, int? destinationId) async {
    destinations.add((fileId, destinationId));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(String storagePath) async {
    fetched.add(storagePath);
    return ApiSuccess(bytes ?? Uint8List.fromList([1, 2, 3]));
  }

  final List<int> markedUndecided = [];
  final List<(int, List<Map<String, dynamic>>, String?, double?)> currencies = [];
  List<OutboundFileSummary> undecidedFiles = const [];

  @override
  Future<ApiResult<List<OutboundFileSummary>>> undecided({int? warehouseId}) async => ApiSuccess(undecidedFiles);

  @override
  Future<ApiResult<bool>> markUndecided(int id) async {
    markedUndecided.add(id);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<int>> setCurrency(int id, List<Map<String, dynamic>> lines, {String? currency, double? fxCnyJpy}) async {
    currencies.add((id, lines, currency, fxCnyJpy));
    return ApiSuccess(lines.length);
  }
}
