import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/reports/data/work_log_repository.dart';

/// 作業実績 (0215) in memory: [entries] for any month; what was asked is kept.
class FakeWorkLogRepository implements WorkLogRepository {
  FakeWorkLogRepository([this.entries = const []]);

  List<WorkLogEntry> entries;
  final List<({DateTime from, DateTime to, int? warehouseId, bool amounts})> asked = [];

  @override
  Future<ApiResult<List<WorkLogEntry>>> list({
    required DateTime from,
    required DateTime to,
    int? warehouseId,
    bool amounts = false,
  }) async {
    asked.add((from: from, to: to, warehouseId: warehouseId, amounts: amounts));
    return ApiSuccess(entries);
  }
}
