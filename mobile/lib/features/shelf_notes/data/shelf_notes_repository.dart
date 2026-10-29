import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../auth/application/auth_controller.dart';
import '../../delivery/application/delivery_providers.dart';

/// 棚メモ (0167): where something special was put, written freely — a
/// product, a place, and the note as bullets.
class ShelfNote extends Equatable {
  const ShelfNote({
    required this.id,
    required this.body,
    this.productId,
    this.janCode,
    this.location,
    this.createdAt,
    this.createdByName,
    this.updatedAt,
    this.updatedByName,
  });

  final int id;
  final int? productId;
  final String? janCode;
  final String? location;
  final String body;
  final DateTime? createdAt;
  final String? createdByName;
  final DateTime? updatedAt;
  final String? updatedByName;

  factory ShelfNote.fromJson(Map<String, dynamic> j) => ShelfNote(
        id: (j['id'] as num).toInt(),
        productId: (j['product_id'] as num?)?.toInt(),
        janCode: j['jan_code'] as String?,
        location: j['location'] as String?,
        body: '${j['body'] ?? ''}',
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
        createdByName: j['created_by_name'] as String?,
        updatedAt: DateTime.tryParse('${j['updated_at'] ?? ''}')?.toLocal(),
        updatedByName: j['updated_by_name'] as String?,
      );

  /// Whether [query] is in it (place, note, JAN, or the product's names given).
  bool matches(String query, {Iterable<String> productTexts = const []}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [location ?? '', body, janCode ?? '', ...productTexts].any((t) => t.toLowerCase().contains(q));
  }

  @override
  List<Object?> get props => [id, productId, janCode, location, body, createdAt, createdByName, updatedAt, updatedByName];
}

abstract class ShelfNotesRepository {
  Future<ApiResult<List<ShelfNote>>> list();
  Future<ApiResult<ShelfNote>> save({int? id, int? productId, String? location, required String body});
  Future<ApiResult<void>> remove(int id);
}

class ShelfNotesRepositoryImpl implements ShelfNotesRepository {
  ShelfNotesRepositoryImpl(this._rest);

  final Dio _rest;

  @override
  Future<ApiResult<List<ShelfNote>>> list() async {
    try {
      final r = await _rest.get('/shelf_notes',
          queryParameters: {'select': '*', 'removed_at': 'is.null', 'order': 'created_at.desc', 'limit': '2000'});
      return ApiSuccess([
        for (final e in (r.data as List? ?? const []).whereType<Map>()) ShelfNote.fromJson(e.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<ShelfNote>> save({int? id, int? productId, String? location, required String body}) async {
    try {
      final r = await _rest.post('/rpc/save_shelf_note', data: {
        'p': {'id': id, 'product_id': productId, 'location': location, 'body': body},
      });
      return ApiSuccess(ShelfNote.fromJson((r.data as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<void>> remove(int id) async {
    try {
      await _rest.post('/rpc/remove_shelf_note', data: {'p_id': id});
      return const ApiSuccess(null);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }
}

final shelfNotesRepositoryProvider =
    Provider<ShelfNotesRepository>((ref) => ShelfNotesRepositoryImpl(ref.watch(restDioProvider)));

final shelfNotesProvider = FutureProvider.autoDispose<List<ShelfNote>>((ref) async {
  final r = await ref.watch(shelfNotesRepositoryProvider).list();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// Who may write notes (as can_write_shelf_notes).
final canWriteShelfNotesProvider = Provider<bool>((ref) {
  final p = ref.watch(authControllerProvider).user?.permissions ?? const <String>[];
  return const ['putaway.confirm', 'inventory.adjust', 'product.manage'].any(p.contains);
});
