import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/profit/data/profit_repository.dart';
import 'package:wms_mobile/features/profit/domain/monthly_profit.dart';

/// 月ごとの収益 (0211) in memory: the rows given, whatever the period.
class FakeProfitRepository implements ProfitRepository {
  FakeProfitRepository([this.rows = const []]);

  final List<ProfitRow> rows;
  final List<({DateTime from, DateTime to, int? warehouseId})> asked = [];

  @override
  Future<ApiResult<List<ProfitRow>>> byMonth({required DateTime from, required DateTime to, int? warehouseId}) async {
    asked.add((from: from, to: to, warehouseId: warehouseId));
    return ApiSuccess(rows);
  }
}
