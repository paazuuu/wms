import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../auth/application/auth_controller.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../evidence/data/evidence_repository.dart' show evidenceBucket;
import '../../master_import/data/master_import_repository.dart' show masterImportBucket;
import '../domain/tax_purchases.dart';

abstract class TaxFilesRepository {
  /// The invoices taken into stock whose month lies from [from] to [to].
  Future<ApiResult<List<TaxPurchase>>> purchases(DateTime from, DateTime to);

  /// An invoice's original: the evidence copy, else the import's own.
  Future<ApiResult<Uint8List>> original(TaxPurchase p);
}

class TaxFilesRepositoryImpl implements TaxFilesRepository {
  TaxFilesRepositoryImpl(this._rest, this._storage);

  final Dio _rest;
  final Dio _storage;

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<ApiResult<List<TaxPurchase>>> purchases(DateTime from, DateTime to) async {
    try {
      final r = await _rest.post('/rpc/tax_purchases', data: {'p_from': _day(from), 'p_to': _day(to)});
      final raw = r.data is List && (r.data as List).length == 1 && (r.data as List).first is List ? (r.data as List).first : r.data;
      return ApiSuccess([
        for (final e in (raw as List? ?? const []).whereType<Map>()) TaxPurchase.fromJson(e.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<Uint8List>> original(TaxPurchase p) async {
    final tries = [
      if (p.evidencePath case final e?) '$evidenceBucket/$e',
      if (p.originalPath case final o?) '$masterImportBucket/$o',
    ];
    DioException? last;
    for (final path in tries) {
      try {
        final r = await _storage.get<List<int>>('/object/authenticated/$path', options: Options(responseType: ResponseType.bytes));
        return ApiSuccess(Uint8List.fromList(r.data ?? const []));
      } on DioException catch (e) {
        last = e;
      }
    }
    return last == null ? const ApiFailure(message: 'no original file') : mapDioError(last);
  }
}

final taxFilesRepositoryProvider =
    Provider<TaxFilesRepository>((ref) => TaxFilesRepositoryImpl(ref.watch(restDioProvider), ref.watch(storageDioProvider)));

/// Who may see the books (as can_view_purchase_books).
final canViewPurchaseBooksProvider = Provider<bool>((ref) {
  final p = ref.watch(authControllerProvider).user?.permissions ?? const <String>[];
  return const ['inventory.adjust', 'report.view', 'user.manage'].any(p.contains);
});

/// One year's months (newest first).
final taxMonthsProvider = FutureProvider.autoDispose.family<List<TaxMonth>, int>((ref, year) async {
  final r = await ref.watch(taxFilesRepositoryProvider).purchases(DateTime(year), DateTime(year, 12, 31));
  return r.when(success: TaxMonth.group, failure: (f) => throw Exception(f.message));
});
