import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/product_repository.dart';
import '../domain/data_quality.dart';
import '../domain/product.dart';
import '../domain/product_lot.dart';
import '../domain/warehouse_product.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(ref.watch(restDioProvider));
});

/// Free-text filter over name/JAN; empty shows every product in scope.
final productSearchProvider = StateProvider<String>((_) => '');

/// Whether the list also shows deactivated products.
final showInactiveProductsProvider = StateProvider<bool>((_) => false);

/// The unit vocabulary a pack size is chosen from (`list_uoms`, 0059). Global
/// and effectively static, so it is fetched once per screen rather than filtered.
final uomVocabularyProvider = FutureProvider.autoDispose<List<Uom>>((ref) async {
  final result = await ref.watch(productRepositoryProvider).listUoms();
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// The lots recorded against one product (0060), soonest expiry first.
final productLotsProvider =
    FutureProvider.autoDispose.family<List<ProductLot>, int>((ref, productId) async {
  final result = await ref.watch(productRepositoryProvider).lots(productId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// Which serial status the detail screen is filtering by; null shows every one.
final serialStatusFilterProvider = StateProvider<String?>((_) => null);

/// The serial numbers recorded against one product (0060).
final productSerialsProvider = FutureProvider.autoDispose
    .family<List<ProductSerial>, int>((ref, productId) async {
  final status = ref.watch(serialStatusFilterProvider);
  final result = await ref
      .watch(productRepositoryProvider)
      .serials(productId, status: status);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// How this product is handled in the *active* warehouse (0063), or null when
/// there is no active warehouse or no settings for it there.
///
/// Warehouse-scoped on purpose: §22's whole point is that the answer differs per
/// building, so the screen shows the one the operator is actually working in.
final warehouseProductProvider = FutureProvider.autoDispose
    .family<WarehouseProduct?, int>((ref, productId) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  if (warehouseId == null) return null;
  final result = await ref.watch(productRepositoryProvider).warehouseSettings(
        warehouseId: warehouseId,
        productId: productId,
      );
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// JAN codes in use system-wide that no product accounts for, worst first
/// (`unlinked_jan_codes`, 0058) — the worklist for registering master data.
final unlinkedJanCodesProvider =
    FutureProvider.autoDispose<List<UnlinkedJan>>((ref) async {
  final result = await ref.watch(productRepositoryProvider).unlinkedJanCodes();
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// How complete `product_id` is next to `jan_code`, system-wide
/// (`product_id_coverage`, 0058) — [unlinkedJanCodesProvider]'s own summary.
final productIdCoverageProvider =
    FutureProvider.autoDispose<ProductIdCoverage>((ref) async {
  final result = await ref.watch(productRepositoryProvider).productIdCoverage();
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// The product master filtered by [productSearchProvider] and
/// [showInactiveProductsProvider], name-sorted.
final productListProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final search = ref.watch(productSearchProvider);
  final showInactive = ref.watch(showInactiveProductsProvider);
  final result = await ref.watch(productRepositoryProvider).list(
        search: search.isEmpty ? null : search,
        status: showInactive ? null : 'active',
      );
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
