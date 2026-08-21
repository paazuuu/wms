import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../products/application/product_providers.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_stock_ui.dart';
import 'stock_adjustment_form_screen.dart';

/// Step one of a stock adjustment: find the product to adjust by scanning or
/// typing a barcode / SKU / name. Reuses the products search provider so the
/// lookup behaviour stays identical to Product Lookup.
class StockAdjustmentSearchScreen extends ConsumerStatefulWidget {
  const StockAdjustmentSearchScreen({super.key});

  @override
  ConsumerState<StockAdjustmentSearchScreen> createState() =>
      _StockAdjustmentSearchScreenState();
}

class _StockAdjustmentSearchScreenState
    extends ConsumerState<StockAdjustmentSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final next = _controller.text.trim();
    if (next == _query) {
      ref.invalidate(productSearchProvider(_query));
    } else {
      setState(() => _query = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(productSearchProvider(_query));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featStockAdjustment)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ScanField(
              controller: _controller,
              autofocusOnWide: true,
              clearOnSubmit: false,
              hintText: l10n.scanTypeHint,
              onSubmitted: (_) => _submit(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(productSearchProvider(_query)),
              child: results.when(
                data: (items) => items.isEmpty
                    ? EmptyStateView(
                        icon: Icons.search_off,
                        title: _query.isEmpty
                            ? l10n.findProductToAdjust
                            : l10n.noMatchesFor(_query),
                        message: l10n.scanTypeMessage,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) =>
                            _AdjustCandidateCard(product: items[index]),
                      ),
                loading: () => LoadingView(message: l10n.searching),
                error: (error, _) => ErrorStateView(
                  message: '$error',
                  onRetry: () => ref.invalidate(productSearchProvider(_query)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustCandidateCard extends StatelessWidget {
  const _AdjustCandidateCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stock = ProductStockUi.of(product);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StockAdjustmentFormScreen(product: product),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              StatusAvatar(tone: stock.tone, icon: stock.icon),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.sku,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFamily: 'FiraCode',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(
                tone: stock.tone,
                label: '${product.displayStock}',
                icon: stock.icon,
                dense: true,
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
