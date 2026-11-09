import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../domain/monthly_profit.dart';

/// 月ごとの収益 (0211): every shipment's lines, priced at what they sold for
/// and what they were bought for, one row per month and product.
abstract class ProfitRepository {
  Future<ApiResult<List<ProfitRow>>> byMonth({required DateTime from, required DateTime to, int? warehouseId});
}

class ProfitRepositoryImpl implements ProfitRepository {
  ProfitRepositoryImpl(this._rest);

  final Dio _rest;

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<ApiResult<List<ProfitRow>>> byMonth({required DateTime from, required DateTime to, int? warehouseId}) async {
    try {
      final r = await _rest.post('/rpc/profit_by_month',
          data: {'p_from': _day(from), 'p_to': _day(to), 'p_warehouse_id': warehouseId});
      final list = r.data is List ? r.data as List : const [];
      return ApiSuccess([for (final e in list.whereType<Map>()) ProfitRow.fromJson(e.cast<String, dynamic>())]);
    } on DioException catch (e) {
      return mapDioError<List<ProfitRow>>(e);
    }
  }
}

final profitRepositoryProvider = Provider<ProfitRepository>((ref) => ProfitRepositoryImpl(ref.watch(restDioProvider)));

/// The last [months] months up to this one, for [warehouseId] (null: all).
final monthlyProfitProvider =
    FutureProvider.autoDispose.family<List<ProfitRow>, ({int months, int? warehouseId})>((ref, q) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month - q.months + 1, 1);
  final to = DateTime(now.year, now.month + 1, 0);
  final r = await ref.watch(profitRepositoryProvider).byMonth(from: from, to: to, warehouseId: q.warehouseId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
