import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/stock_import/data/jan_by_code_repository.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_file.dart';

/// JANs by 品番 (0221) without a server: [byCode] says which.
class FakeJanByCodeRepository implements JanByCodeRepository {
  FakeJanByCodeRepository([this.byCode = const {}]);

  final Map<String, JanByCode> byCode;
  final asked = <List<ReadRow>>[];

  @override
  Future<ApiResult<Map<int, JanByCode>>> find(List<ReadRow> rows) async {
    asked.add(rows);
    return ApiSuccess({
      for (final r in rows)
        if (r.jan.trim().isEmpty && byCode.containsKey(r.code.trim())) r.lineNo: byCode[r.code.trim()]!,
    });
  }
}
