import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => CatalogRepositoryImpl(ref.watch(restDioProvider)));

final catalogSearchProvider = StateProvider<String>((_) => '');

final catalogListProvider = FutureProvider.autoDispose<List<CatalogItem>>((ref) async {
  final q = ref.watch(catalogSearchProvider);
  final r = await ref.watch(catalogRepositoryProvider).list(search: q.isEmpty ? null : q);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

final catalogHistoryProvider = FutureProvider.autoDispose.family<List<CatalogTerm>, int>((ref, id) async {
  final r = await ref.watch(catalogRepositoryProvider).history(id);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// Whether an item is in the product master yet.
enum CatalogMasterFilter { all, inMaster, notInMaster }

enum CatalogStockFilter { all, inStock, none }

/// What the library shows: by maker, supplier, whether it is in the master,
/// and stock. Empty sets mean any.
class CatalogFilter extends Equatable {
  const CatalogFilter({
    this.makers = const {},
    this.supplierIds = const {},
    this.master = CatalogMasterFilter.all,
    this.stock = CatalogStockFilter.all,
  });

  final Set<String> makers;
  final Set<int> supplierIds;
  final CatalogMasterFilter master;
  final CatalogStockFilter stock;

  bool matches(CatalogItem i) {
    if (makers.isNotEmpty && !makers.contains(i.maker ?? '')) return false;
    if (supplierIds.isNotEmpty && !i.terms.any((t) => supplierIds.contains(t.partnerId))) return false;
    switch (master) {
      case CatalogMasterFilter.inMaster when !i.inMaster:
      case CatalogMasterFilter.notInMaster when i.inMaster:
        return false;
      default:
    }
    final onHand = i.stock?.onHand ?? 0;
    return switch (stock) {
      CatalogStockFilter.all => true,
      CatalogStockFilter.inStock => onHand > 0,
      CatalogStockFilter.none => onHand <= 0,
    };
  }

  CatalogFilter copyWith({Set<String>? makers, Set<int>? supplierIds, CatalogMasterFilter? master, CatalogStockFilter? stock}) =>
      CatalogFilter(
        makers: makers ?? this.makers,
        supplierIds: supplierIds ?? this.supplierIds,
        master: master ?? this.master,
        stock: stock ?? this.stock,
      );

  @override
  List<Object?> get props => [makers, supplierIds, master, stock];
}

final catalogFilterProvider = StateProvider<CatalogFilter>((_) => const CatalogFilter());

final filteredCatalogProvider = Provider.autoDispose<AsyncValue<List<CatalogItem>>>((ref) {
  final f = ref.watch(catalogFilterProvider);
  return ref.watch(catalogListProvider).whenData((all) => [for (final i in all) if (f.matches(i)) i]);
});
