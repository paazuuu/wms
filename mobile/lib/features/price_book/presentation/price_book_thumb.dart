import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/price_book_providers.dart';
import '../domain/price_book.dart';

/// A price book item's face (0125): its own first picture, else its product's,
/// signed with the rest of the list. Without one a plain box keeps its place.
class PriceBookThumb extends ConsumerWidget {
  const PriceBookThumb({super.key, required this.item, this.size = 56});

  final PriceBookItem item;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final path = item.facePath;
    final url = path == null ? null : ref.watch(priceBookFaceUrlsProvider).valueOrNull?[path];
    final radius = BorderRadius.circular(size >= 64 ? 10 : 6);
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: radius),
      child: Icon(Icons.inventory_2_outlined, size: size * 0.5, color: theme.colorScheme.onSurfaceVariant),
    );
    if (url == null) return placeholder;
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        key: ValueKey('cl-thumb-img-${item.id}'),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
