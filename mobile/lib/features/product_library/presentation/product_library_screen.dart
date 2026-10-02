import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_library_providers.dart';
import '../domain/product_image.dart';
import 'product_gallery_screen.dart';
import '../../../core/ui/product_name.dart';
import 'product_thumb.dart';

/// 商品ライブラリー (0109): every product with its face, so pictures can be
/// found, checked and added. "写真なしのみ" narrows to the products still
/// without one — the list to work through when setting the library up.
class ProductLibraryScreen extends StatelessWidget {
  const ProductLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).featProductLibrary)),
        body: const ProductLibraryView(),
      );
}

/// The products as a grid of pictures, searchable and narrowed to those
/// still without one. [onOpen] decides what a tap opens — the product
/// screen when this is the photo view of 商品ライブラリー, the pictures
/// otherwise.
class ProductLibraryView extends ConsumerStatefulWidget {
  const ProductLibraryView({super.key, this.onOpen});

  final void Function(LibraryProduct product)? onOpen;

  @override
  ConsumerState<ProductLibraryView> createState() => _ProductLibraryViewState();
}

class _ProductLibraryViewState extends ConsumerState<ProductLibraryView> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _withoutImages = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = (query: _query, withoutImages: _withoutImages);
    final async = ref.watch(productLibraryProvider(q));
    return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: TextField(
            key: const ValueKey('pl-search'),
            controller: _search,
            onChanged: _onSearch,
            onSubmitted: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.plSearchHint, isDense: true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(children: [
            FilterChip(
              key: const ValueKey('pl-without-images'),
              label: Text(l10n.plWithoutImages),
              selected: _withoutImages,
              onSelected: (v) => setState(() => _withoutImages = v),
            ),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => LoadingView(message: l10n.loading),
            error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(productLibraryProvider(q))),
            data: (rows) => rows.isEmpty
                ? EmptyStateView(icon: Icons.photo_library_outlined, title: l10n.plNoProducts)
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(productLibraryProvider(q)),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisExtent: 250,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                      ),
                      itemCount: rows.length,
                      itemBuilder: (_, i) => _ProductCard(product: rows[i], onOpen: widget.onOpen),
                    ),
                  ),
          ),
        ),
      ]);
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, this.onOpen});

  final LibraryProduct product;
  final void Function(LibraryProduct product)? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = product;
    return Card(
      key: ValueKey('pl-product-${p.id}'),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen != null
            ? () => onOpen!(p)
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProductGalleryScreen(productId: p.id, productName: p.name, janCode: p.janCode),
                )),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => Center(
                child: ProductThumb(productId: p.id, janCode: p.janCode, productName: p.name, size: c.maxHeight < c.maxWidth ? c.maxHeight : c.maxWidth, openOnTap: false),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ProductNameText(name: p.name, nameEn: p.nameEn, names: p.names, maxLines: 1, style: theme.textTheme.titleSmall),
              Text([if (p.maker != null) p.maker!, if (p.janCode != null) p.janCode!].join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              Text(p.imageCount == 0 ? l10n.plNoImages : l10n.plImageCount(p.imageCount),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: p.imageCount == 0 ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
    );
  }
}
