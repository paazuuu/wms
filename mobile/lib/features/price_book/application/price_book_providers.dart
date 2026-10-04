import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../product_library/application/product_library_providers.dart';
import '../data/price_book_repository.dart';
import '../domain/price_book.dart';

final priceBookRepositoryProvider = Provider<PriceBookRepository>((ref) => PriceBookRepositoryImpl(ref.watch(restDioProvider)));

final priceBookSearchProvider = StateProvider<String>((_) => '');

final priceBookListProvider = FutureProvider.autoDispose<List<PriceBookItem>>((ref) async {
  final q = ref.watch(priceBookSearchProvider);
  final r = await ref.watch(priceBookRepositoryProvider).list(search: q.isEmpty ? null : q);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

final priceBookHistoryProvider = FutureProvider.autoDispose.family<List<PriceBookTerm>, int>((ref, id) async {
  final r = await ref.watch(priceBookRepositoryProvider).history(id);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// Whether an item is in the product master yet.
enum PriceBookMasterFilter { all, inMaster, notInMaster }

enum PriceBookStockFilter { all, inStock, none }

/// What the price book shows: by maker, supplier, whether it is in the master,
/// and stock. Empty sets mean any.
class PriceBookFilter extends Equatable {
  const PriceBookFilter({
    this.makers = const {},
    this.supplierIds = const {},
    this.master = PriceBookMasterFilter.all,
    this.stock = PriceBookStockFilter.all,
  });

  final Set<String> makers;
  final Set<int> supplierIds;
  final PriceBookMasterFilter master;
  final PriceBookStockFilter stock;

  bool matches(PriceBookItem i) {
    if (makers.isNotEmpty && !makers.contains(i.maker ?? '')) return false;
    if (supplierIds.isNotEmpty && !i.terms.any((t) => supplierIds.contains(t.partnerId))) return false;
    switch (master) {
      case PriceBookMasterFilter.inMaster when !i.inMaster:
      case PriceBookMasterFilter.notInMaster when i.inMaster:
        return false;
      default:
    }
    final onHand = i.stock?.onHand ?? 0;
    return switch (stock) {
      PriceBookStockFilter.all => true,
      PriceBookStockFilter.inStock => onHand > 0,
      PriceBookStockFilter.none => onHand <= 0,
    };
  }

  PriceBookFilter copyWith({Set<String>? makers, Set<int>? supplierIds, PriceBookMasterFilter? master, PriceBookStockFilter? stock}) =>
      PriceBookFilter(
        makers: makers ?? this.makers,
        supplierIds: supplierIds ?? this.supplierIds,
        master: master ?? this.master,
        stock: stock ?? this.stock,
      );

  @override
  List<Object?> get props => [makers, supplierIds, master, stock];
}

final priceBookFilterProvider = StateProvider<PriceBookFilter>((_) => const PriceBookFilter());

final filteredPriceBookProvider = Provider.autoDispose<AsyncValue<List<PriceBookItem>>>((ref) {
  final f = ref.watch(priceBookFilterProvider);
  return ref.watch(priceBookListProvider).whenData((all) => [for (final i in all) if (f.matches(i)) i]);
});

/// List or pictures: the same items, drawn two ways (0125).
final priceBookPhotoViewProvider = StateProvider<bool>((_) => false);

/// Viewable URLs for the faces of the items listed, signed in one call.
final priceBookFaceUrlsProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final items = await ref.watch(priceBookListProvider.future);
  final paths = {for (final i in items) if (i.facePath != null) i.facePath!}.toList();
  if (paths.isEmpty) return const {};
  final r = await ref.watch(productImageRepositoryProvider).signUrls(paths);
  return r.when(success: (m) => m, failure: (_) => const <String, String>{});
});
