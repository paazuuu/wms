import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';

/// One piece of a month's work (0215): a receipt read from a file, a list
/// shipped or planned, or a warehouse memo — with the notes written on it.
class WorkLogEntry {
  const WorkLogEntry({
    required this.kind,
    required this.day,
    this.docDay,
    this.warehouseId,
    this.warehouseName,
    this.partner,
    this.fileName,
    this.lines,
    this.quantity,
    this.short,
    this.cartons,
    this.status,
    this.note,
    this.amount,
    this.currency,
    this.fee,
    this.freight,
    this.by,
  });

  /// receipt, unplanned (予定外の入荷), outbound, proxy (在庫外出荷), memo.
  final String kind;
  final DateTime day;

  /// The date on a receipt's document, when it has one.
  final DateTime? docDay;
  final int? warehouseId;
  final String? warehouseName;

  /// The supplier of a receipt, where a list went.
  final String? partner;
  final String? fileName;
  final int? lines;
  final int? quantity;
  final int? short;
  final int? cartons;
  final String? status;
  final String? note;

  /// Only when asked for and allowed to see prices.
  final double? amount;
  final String? currency;
  final double? fee;
  final double? freight;
  final String? by;

  static int? _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
  static double? _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
  static String? _s(Object? v) => v == null || '$v'.trim().isEmpty ? null : '$v';

  factory WorkLogEntry.fromJson(Map<String, dynamic> j) => WorkLogEntry(
        kind: '${j['kind'] ?? 'memo'}',
        day: DateTime.tryParse('${j['day'] ?? ''}') ?? DateTime(2000),
        docDay: DateTime.tryParse('${j['doc_day'] ?? ''}'),
        warehouseId: _i(j['warehouse_id']),
        warehouseName: _s(j['warehouse_name']),
        partner: _s(j['partner']),
        fileName: _s(j['file_name']),
        lines: _i(j['lines']),
        quantity: _i(j['quantity']),
        short: _i(j['short']),
        cartons: _i(j['cartons']),
        status: _s(j['status']),
        note: _s(j['note']),
        amount: _d(j['amount']),
        currency: _s(j['currency']),
        fee: _d(j['fee']),
        freight: _d(j['freight']),
        by: _s(j['by']),
      );
}

abstract class WorkLogRepository {
  Future<ApiResult<List<WorkLogEntry>>> list({
    required DateTime from,
    required DateTime to,
    int? warehouseId,
    bool amounts = false,
  });
}

class WorkLogRepositoryImpl implements WorkLogRepository {
  WorkLogRepositoryImpl(this._rest);

  final Dio _rest;

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<ApiResult<List<WorkLogEntry>>> list({
    required DateTime from,
    required DateTime to,
    int? warehouseId,
    bool amounts = false,
  }) async {
    try {
      final r = await _rest.post('/rpc/work_log', data: {
        'p_from': _day(from),
        'p_to': _day(to),
        'p_warehouse_id': warehouseId,
        'p_amounts': amounts,
      });
      final list = r.data is List ? r.data as List : const [];
      return ApiSuccess([for (final e in list.whereType<Map>()) WorkLogEntry.fromJson(e.cast<String, dynamic>())]);
    } on DioException catch (e) {
      return mapDioError<List<WorkLogEntry>>(e);
    }
  }
}

final workLogRepositoryProvider = Provider<WorkLogRepository>((ref) => WorkLogRepositoryImpl(ref.watch(restDioProvider)));
