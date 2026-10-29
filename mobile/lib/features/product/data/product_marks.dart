import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../auth/application/auth_controller.dart';
import '../../delivery/application/delivery_providers.dart';

/// ★ and ⚠ on a product (0167).
abstract class ProductMarksRepository {
  Future<ApiResult<void>> setMarks(int productId, Set<String> marks, {String? note});
}

class ProductMarksRepositoryImpl implements ProductMarksRepository {
  ProductMarksRepositoryImpl(this._rest);

  final Dio _rest;

  @override
  Future<ApiResult<void>> setMarks(int productId, Set<String> marks, {String? note}) async {
    try {
      await _rest.post('/rpc/set_product_marks',
          data: {'p_product_id': productId, 'p_marks': marks.toList()..sort(), 'p_note': note});
      return const ApiSuccess(null);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }
}

final productMarksRepositoryProvider =
    Provider<ProductMarksRepository>((ref) => ProductMarksRepositoryImpl(ref.watch(restDioProvider)));

/// Who may set marks: whoever handles goods (as can_mark_products).
final canMarkProductsProvider = Provider<bool>((ref) {
  final p = ref.watch(authControllerProvider).user?.permissions ?? const <String>[];
  return const ['product.manage', 'inspection.confirm', 'receiving.confirm', 'putaway.confirm', 'inventory.adjust']
      .any(p.contains);
});
