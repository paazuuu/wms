import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/error_log/data/error_log_repository.dart';

/// エラーログ in memory (0227): removal erases, by id or by age.
class FakeErrorLogRepository implements ErrorLogRepository {
  FakeErrorLogRepository([List<AppErrorEntry> start = const []]) : entries = List.of(start);

  final List<AppErrorEntry> entries;
  final askedDays = <int?>[];
  final removedIds = <int>[];
  int? removedOlderThan;

  @override
  Future<ApiResult<List<AppErrorEntry>>> list({int? days}) async {
    askedDays.add(days);
    final since = days == null ? null : DateTime.now().subtract(Duration(days: days));
    return ApiSuccess([
      for (final e in entries..sort((a, b) => b.lastAt.compareTo(a.lastAt)))
        if (since == null || e.lastAt.isAfter(since)) e,
    ]);
  }

  @override
  Future<ApiResult<int>> remove({List<int> ids = const [], int? olderThanDays}) async {
    final before = entries.length;
    removedIds.addAll(ids);
    entries.removeWhere((e) => ids.contains(e.id));
    if (olderThanDays != null) {
      removedOlderThan = olderThanDays;
      final cut = DateTime.now().subtract(Duration(days: olderThanDays));
      entries.removeWhere((e) => e.lastAt.isBefore(cut));
    }
    return ApiSuccess(before - entries.length);
  }
}
