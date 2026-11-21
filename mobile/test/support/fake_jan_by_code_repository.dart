import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/stock_import/data/jan_by_code_repository.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_file.dart';

/// JANs by 品番 (0221) without a server: [byCode] says which.
class FakeJanByCodeRepository implements JanByCodeRepository {
  FakeJanByCodeRepository([this.byCode = const {}, this.onWeb = const {}]);

  final Map<String, JanByCode> byCode;

  /// What the web gives, by 品番.
  final Map<String, String> onWeb;
  final asked = <List<ReadRow>>[];
  final askedOnWeb = <List<ReadRow>>[];

  @override
  Future<ApiResult<Map<int, JanByCode>>> findOnWeb(List<ReadRow> rows,
      {void Function(int done, int total)? onProgress}) async {
    final ask = [for (final r in rows) if (r.jan.trim().isEmpty && r.code.trim().isNotEmpty) r];
    askedOnWeb.add(ask);
    onProgress?.call(ask.length, ask.length);
    return ApiSuccess({
      for (final r in ask)
        if (onWeb.containsKey(r.code.trim())) r.lineNo: (jan: onWeb[r.code.trim()]!, source: 'web'),
    });
  }

  @override
  Future<ApiResult<Map<int, JanByCode>>> find(List<ReadRow> rows) async {
    asked.add(rows);
    return ApiSuccess({
      for (final r in rows)
        if (r.jan.trim().isEmpty && byCode.containsKey(r.code.trim())) r.lineNo: byCode[r.code.trim()]!,
    });
  }
}
