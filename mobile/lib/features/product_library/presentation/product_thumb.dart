import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/product_library_providers.dart';
import 'product_gallery_screen.dart';

/// A product's face (0109), put in front of its name on every screen that
/// lists goods. Found by product id, or by JAN for a line not yet linked to
/// a product. Without a picture it keeps its place with a plain box, so the
/// names still line up. Tapping it opens the product's pictures.
class ProductThumb extends ConsumerWidget {
  const ProductThumb({super.key, this.productId, this.janCode, this.productName, this.size = 40, this.openOnTap = true});

  final int? productId;
  final String? janCode;
  final String? productName;
  final double size;
  final bool openOnTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final key = ProductFaceCache.keyFor(productId: productId, janCode: janCode);
    final entry = key == null ? null : ref.watch(productFaceCacheProvider.select((m) => m[key]));
    if (key != null) ref.read(productFaceCacheProvider.notifier).request(productId: productId, janCode: janCode);
    final radius = BorderRadius.circular(size >= 64 ? 10 : 6);
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: radius,
      ),
      child: Icon(Icons.inventory_2_outlined, size: size * 0.5, color: theme.colorScheme.onSurfaceVariant),
    );
    final url = entry?.url;
    final Widget image = url == null
        ? placeholder
        : ClipRRect(
            borderRadius: radius,
            child: Image.network(
              url,
              key: ValueKey('product-thumb-img-${entry?.productId}'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, __, ___) => placeholder,
            ),
          );
    final pid = productId ?? entry?.productId;
    final tappable = openOnTap && pid != null && url != null;
    return Semantics(
      image: true,
      label: productName,
      child: InkWell(
        key: ValueKey('product-thumb-${pid ?? janCode}'),
        borderRadius: radius,
        onTap: tappable
            ? () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProductGalleryScreen(productId: pid, productName: productName, janCode: janCode),
                ))
            : null,
        child: image,
      ),
    );
  }
}

/// A product line's leading block: the face, then the name and whatever
/// sits under it. For screens whose rows are not ListTiles.
class ProductWithThumb extends StatelessWidget {
  const ProductWithThumb({super.key, this.productId, this.janCode, this.productName, required this.child, this.size = 40});

  final int? productId;
  final String? janCode;
  final String? productName;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProductThumb(productId: productId, janCode: janCode, productName: productName, size: size),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      );
}
