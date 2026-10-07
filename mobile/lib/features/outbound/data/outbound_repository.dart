import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../domain/outbound.dart';

/// 出庫の提案 and saved destinations (0139).
abstract class OutboundRepository {
  Future<ApiResult<List<ShipDestination>>> destinations({String? search});
  Future<ApiResult<int>> saveDestination(ShipDestination d);
  Future<ApiResult<bool>> retireDestination(int id);

  /// What each product has in [warehouseId], and what is free to send.
  Future<ApiResult<List<OutboundStockItem>>> stock(int warehouseId);

  /// The proposal as an open shipment. [lines] maps JAN → quantity;
  /// [prices] JAN → 出荷単価, and [snapshots] JAN → the prices it was
  /// worked out from ({cost, list, sell}) (0142).
  Future<ApiResult<OutboundCreated>> create({
    required int warehouseId,
    required Map<String, int> lines,
    Map<String, double> prices = const {},
    Map<String, Map<String, double?>> snapshots = const {},
    int? destinationId,
    Map<String, dynamic>? shipTo,
    String? shipDate,
    String? note,
    Map<String, dynamic>? proposal,
  });

  /// A shipment's destination and lines, for the sheet.
  Future<ApiResult<OutboundSheet>> sheet(int shipmentId);

  /// Every product's stock in [warehouseId], or in every warehouse allowed.
  Future<ApiResult<List<StockExportRow>>> stockExport({int? warehouseId});
}

class OutboundRepositoryImpl implements OutboundRepository {
  OutboundRepositoryImpl(this._rest);

  final Dio _rest;

  static Object? _one(Object? d) => d is List && d.isNotEmpty && d.first is! Map ? d.first : d;

  Future<ApiResult<T>> _rpc<T>(String name, Map<String, dynamic> body, T Function(Object? data) read) async {
    try {
      final r = await _rest.post('/rpc/$name', data: body);
      return ApiSuccess(read(r.data));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  static List<Map<String, dynamic>> _rows(Object? d) => [
        for (final e in (d is List ? d : const []).whereType<Map>()) e.cast<String, dynamic>(),
      ];

  @override
  Future<ApiResult<List<ShipDestination>>> destinations({String? search}) =>
      _rpc('ship_destinations_list', {'p_search': search?.trim().isEmpty ?? true ? null : search!.trim()},
          (d) => [for (final r in _rows(d)) ShipDestination.fromJson(r)]);

  @override
  Future<ApiResult<int>> saveDestination(ShipDestination d) =>
      _rpc('ship_destination_save', {'p': d.toJson()}, (v) => (_one(v) as num).toInt());

  @override
  Future<ApiResult<bool>> retireDestination(int id) =>
      _rpc('ship_destination_retire', {'p_id': id}, (v) => _one(v) == true);

  @override
  Future<ApiResult<List<OutboundStockItem>>> stock(int warehouseId) =>
      _rpc('outbound_stock', {'p_warehouse_id': warehouseId},
          (d) => [for (final r in _rows(d)) OutboundStockItem.fromJson(r)]);

  @override
  Future<ApiResult<OutboundCreated>> create({
    required int warehouseId,
    required Map<String, int> lines,
    Map<String, double> prices = const {},
    Map<String, Map<String, double?>> snapshots = const {},
    int? destinationId,
    Map<String, dynamic>? shipTo,
    String? shipDate,
    String? note,
    Map<String, dynamic>? proposal,
  }) =>
      _rpc('outbound_create', {
        'p_warehouse_id': warehouseId,
        'p_lines': [
          for (final e in lines.entries)
            if (e.value > 0)
              {
                'jan_code': e.key,
                'quantity': e.value,
                if (prices[e.key] != null) 'unit_price': prices[e.key],
                if (snapshots[e.key] != null) 'price_snapshot': snapshots[e.key],
              },
        ],
        'p_destination_id': destinationId,
        'p_ship_to': shipTo,
        'p_ship_date': shipDate,
        'p_note': note,
        'p_proposal': proposal,
      }, (d) => OutboundCreated.fromJson((d as Map).cast<String, dynamic>()));

  @override
  Future<ApiResult<OutboundSheet>> sheet(int shipmentId) =>
      _rpc('outbound_sheet', {'p_shipment_id': shipmentId},
          (d) => OutboundSheet.fromJson((d as Map).cast<String, dynamic>()));

  @override
  Future<ApiResult<List<StockExportRow>>> stockExport({int? warehouseId}) =>
      _rpc('stock_export', {'p_warehouse_id': warehouseId},
          (d) => [for (final r in _rows(d)) StockExportRow.fromJson(r)]);
}

final outboundRepositoryProvider = Provider<OutboundRepository>((ref) => OutboundRepositoryImpl(ref.watch(restDioProvider)));

final shipDestinationsProvider = FutureProvider.autoDispose<List<ShipDestination>>((ref) async {
  final r = await ref.watch(outboundRepositoryProvider).destinations();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

final outboundStockProvider = FutureProvider.autoDispose.family<List<OutboundStockItem>, int>((ref, warehouseId) async {
  final r = await ref.watch(outboundRepositoryProvider).stock(warehouseId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
