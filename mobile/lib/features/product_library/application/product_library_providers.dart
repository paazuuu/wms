import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../delivery/application/delivery_providers.dart';
import '../data/product_image_repository.dart';
import '../domain/product_image.dart';

final productImageRepositoryProvider = Provider<ProductImageRepository>((ref) => ProductImageRepositoryImpl(
      restDio: ref.watch(restDioProvider),
      storageDio: ref.watch(storageDioProvider),
    ));

/// Adding, ordering and taking down pictures needs product.manage.
final productLibraryCanManageProvider = Provider<bool>((ref) {
  final p = ref.watch(authControllerProvider).user?.permissions ?? const <String>[];
  return p.contains('product.manage');
});

/// A product's face as cached on the device: its viewable URL, or known to
/// have none.
class FaceEntry {
  const FaceEntry({this.productId, this.url, this.path, required this.at});

  final int? productId;
  final String? url;
  final String? path;
  final DateTime at;

  /// Signed URLs live an hour; ask again a little before. A miss is retried
  /// sooner, in case a picture was just added elsewhere.
  bool get fresh => DateTime.now().difference(at) < (url == null ? const Duration(minutes: 5) : const Duration(minutes: 50));
}

/// Every product face any screen asks for, fetched in batches: the rows of
/// a list ask one by one while they build, and one call serves them all.
class ProductFaceCache extends StateNotifier<Map<String, FaceEntry>> {
  ProductFaceCache(this._repo) : super(const {});

  final ProductImageRepository _repo;
  final Set<int> _ids = {};
  final Set<String> _jans = {};
  final Set<String> _inflight = {};
  bool _scheduled = false;

  static String idKey(int id) => 'p:$id';
  static String janKey(String jan) => 'j:${normalizeJanKey(jan)}';

  /// The key a thumbnail for this product is stored under.
  static String? keyFor({int? productId, String? janCode}) {
    if (productId != null) return idKey(productId);
    if (normalizeJanKey(janCode).isNotEmpty) return janKey(janCode!);
    return null;
  }

  /// Safe to call while building: nothing changes until the batch returns.
  void request({int? productId, String? janCode}) {
    final key = keyFor(productId: productId, janCode: janCode);
    if (key == null || _inflight.contains(key) || (state[key]?.fresh ?? false)) return;
    _inflight.add(key);
    if (productId != null) {
      _ids.add(productId);
    } else {
      _jans.add(normalizeJanKey(janCode));
    }
    if (!_scheduled) {
      _scheduled = true;
      Future.microtask(_flush);
    }
  }

  Future<void> _flush() async {
    _scheduled = false;
    final ids = [..._ids];
    final jans = [..._jans];
    _ids.clear();
    _jans.clear();
    if (ids.isEmpty && jans.isEmpty) return;
    final now = DateTime.now();
    final next = <String, FaceEntry>{};
    final faces = await _repo.faces(productIds: ids, jans: jans);
    final list = faces.when(success: (f) => f, failure: (_) => const <ProductFace>[]);
    final urls = await _repo.signUrls([for (final f in list) f.storagePath]);
    final signed = urls.when(success: (m) => m, failure: (_) => const <String, String>{});
    for (final f in list) {
      final e = FaceEntry(productId: f.productId, url: signed[f.storagePath], path: f.storagePath, at: now);
      next[idKey(f.productId)] = e;
      if (f.janCode != null) next[janKey(f.janCode!)] = e;
    }
    for (final id in ids) {
      next.putIfAbsent(idKey(id), () => FaceEntry(productId: id, at: now));
    }
    for (final j in jans) {
      next.putIfAbsent('j:$j', () => FaceEntry(at: now));
    }
    _inflight.removeAll(next.keys);
    _inflight.removeAll([for (final id in ids) idKey(id), for (final j in jans) 'j:$j']);
    if (mounted) state = {...state, ...next};
  }

  /// Faces already known (the library's own list): signed and stored in one go.
  Future<void> prime(List<LibraryProduct> products) async {
    final withFace = [for (final p in products) if (p.facePath != null) p];
    final now = DateTime.now();
    final urls = withFace.isEmpty
        ? const <String, String>{}
        : (await _repo.signUrls([for (final p in withFace) p.facePath!])).when(success: (m) => m, failure: (_) => const <String, String>{});
    final next = <String, FaceEntry>{};
    for (final p in products) {
      final e = FaceEntry(productId: p.id, url: p.facePath == null ? null : urls[p.facePath], path: p.facePath, at: now);
      next[idKey(p.id)] = e;
      if (p.janCode != null) next[janKey(p.janCode!)] = e;
    }
    if (mounted) state = {...state, ...next};
  }

  /// A product's pictures changed: ask again next time it is shown.
  void invalidateProduct(int productId) {
    state = {
      for (final e in state.entries)
        if (e.value.productId != productId && e.key != idKey(productId)) e.key: e.value,
    };
  }
}

final productFaceCacheProvider =
    StateNotifierProvider<ProductFaceCache, Map<String, FaceEntry>>((ref) => ProductFaceCache(ref.watch(productImageRepositoryProvider)));

typedef LibraryQuery = ({String query, bool withoutImages});

final productLibraryProvider = FutureProvider.autoDispose.family<List<LibraryProduct>, LibraryQuery>((ref, q) async {
  final r = await ref.watch(productImageRepositoryProvider).library(query: q.query.isEmpty ? null : q.query, withoutImages: q.withoutImages, limit: 200);
  final rows = r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
  await ref.read(productFaceCacheProvider.notifier).prime(rows);
  return rows;
});

/// A product's pictures in order, each with a viewable URL.
final productGalleryProvider = FutureProvider.autoDispose.family<List<(ProductImage, String?)>, int>((ref, productId) async {
  final repo = ref.watch(productImageRepositoryProvider);
  final images = (await repo.imagesOf(productId)).when(success: (d) => d, failure: (f) => throw Exception(f.message));
  final urls = (await repo.signUrls([for (final i in images) i.storagePath])).when(success: (m) => m, failure: (_) => const <String, String>{});
  return [for (final i in images) (i, urls[i.storagePath])];
});

/// Our attribute master (0110).
final productAttributesProvider = FutureProvider.autoDispose<List<ProductAttributeDef>>((ref) async =>
    (await ref.watch(productImageRepositoryProvider).attributes()).when(success: (d) => d, failure: (f) => throw Exception(f.message)));

/// How this product is called: ours and each supplier's (0110).
final productProfileProvider = FutureProvider.autoDispose.family<ProductProfile, int>((ref, productId) async =>
    (await ref.watch(productImageRepositoryProvider).profile(productId))
        .when(success: (d) => d, failure: (f) => throw Exception(f.message)));
