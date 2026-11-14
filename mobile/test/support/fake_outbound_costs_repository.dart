import 'dart:typed_data';

import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/outbound_file/data/outbound_costs_repository.dart';

/// 輸送費 and the bills behind a list's costs (0214) in memory. [read] is
/// what the AI reads off any bill.
class FakeOutboundCostsRepository implements OutboundCostsRepository {
  FakeOutboundCostsRepository({this.read, this.bytes});

  BillTotals? read;
  Uint8List? bytes;

  final List<(int, double?)> freights = [];
  final List<({int fileId, int warehouseId, OutboundCostKind kind, String name, int size})> added = [];
  final List<int> removed = [];
  final List<int> reads = [];
  final List<String> fetched = [];
  int _next = 100;

  @override
  Future<ApiResult<bool>> setFreight(int fileId, double? amount) async {
    freights.add((fileId, amount));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<OutboundCostFile>> addEvidence({
    required int fileId,
    required int warehouseId,
    required OutboundCostKind kind,
    required String name,
    required Uint8List bytes,
  }) async {
    added.add((fileId: fileId, warehouseId: warehouseId, kind: kind, name: name, size: bytes.length));
    final id = _next++;
    return ApiSuccess(OutboundCostFile(id: id, kind: kind, storagePath: '$warehouseId/$fileId/$id-$name', fileName: name));
  }

  @override
  Future<ApiResult<bool>> removeEvidence(int id) async {
    removed.add(id);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<Uint8List>> evidenceBytes(String storagePath) async {
    fetched.add(storagePath);
    return ApiSuccess(bytes ?? Uint8List.fromList(const [1, 2, 3]));
  }

  @override
  Future<ApiResult<BillTotals?>> readAmount(int costFileId) async {
    reads.add(costFileId);
    return ApiSuccess(read);
  }
}
