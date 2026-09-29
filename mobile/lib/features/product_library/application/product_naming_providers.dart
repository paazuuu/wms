import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/product_naming_repository.dart';
import '../domain/product_naming.dart';

final productNamingRepositoryProvider =
    Provider<ProductNamingRepository>((ref) => ProductNamingRepositoryImpl(ref.watch(restDioProvider)));

/// The naming templates, the default first (0111).
final nameFormatsProvider = FutureProvider.autoDispose<List<NameFormat>>((ref) async =>
    (await ref.watch(productNamingRepositoryProvider).formats()).when(success: (d) => d, failure: (f) => throw Exception(f.message)));

/// Our makers, for renaming.
final makersProvider = FutureProvider.autoDispose.family<List<MakerEntry>, String>((ref, search) async =>
    (await ref.watch(productNamingRepositoryProvider).makers(search: search.isEmpty ? null : search))
        .when(success: (d) => d, failure: (f) => throw Exception(f.message)));

/// A product's naming parts.
final productNamingProvider = FutureProvider.autoDispose.family<ProductNaming, int>((ref, productId) async =>
    (await ref.watch(productNamingRepositoryProvider).naming(productId))
        .when(success: (d) => d, failure: (f) => throw Exception(f.message)));
