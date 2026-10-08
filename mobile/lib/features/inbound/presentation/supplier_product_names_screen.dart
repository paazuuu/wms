import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/application/product_providers.dart';
import '../../product/domain/supplier_product_name.dart';
import '../../product/presentation/product_detail_screen.dart';
import '../../supplier_history/data/supplier_history_repository.dart';
import '../../supplier_history/domain/supplier_history.dart';
import '../../supplier_history/presentation/supplier_detail_screen.dart';

final _supplierNamesProvider = FutureProvider.autoDispose<List<SupplierProductName>>((ref) async {
  final r = await ref.watch(productRepositoryProvider).supplierNames();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// 仕入先商品名 (§38, §40): what every supplier calls our products, kept as
/// they write it, each pointing at one product id. A supplier's Japanese
/// name finds our product here.
///
/// It opens on the suppliers themselves (0143): a card each with what is
/// bought from them, how often and when last. A card opens the supplier —
/// their products and purchases, and the next order from them. The names
/// one by one are the other view.
class SupplierProductNamesScreen extends ConsumerStatefulWidget {
  const SupplierProductNamesScreen({super.key});

  @override
  ConsumerState<SupplierProductNamesScreen> createState() => _SupplierProductNamesScreenState();
}

class _SupplierProductNamesScreenState extends ConsumerState<SupplierProductNamesScreen> {
  String _query = '';
  bool _bySupplier = true;

  bool _cardMatches(SupplierCard c) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [c.name, c.code, c.contactName, ...c.top].any((v) => (v ?? '').toLowerCase().contains(q));
  }

  bool _matches(SupplierProductName n) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [n.supplierDisplayName, n.supplierName, n.supplierCode, n.productName, n.janCode, n.supplierJanCode, n.supplierMaker]
        .any((v) => (v ?? '').toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featSupplierProductNames),
        actions: [
          SegmentedButton<bool>(
            key: const ValueKey('spn-view'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: true, icon: const Icon(Icons.storefront_outlined, size: 18), label: Text(l10n.supViewSuppliers)),
              ButtonSegment(value: false, icon: const Icon(Icons.translate, size: 18), label: Text(l10n.supViewNames)),
            ],
            selected: {_bySupplier},
            onSelectionChanged: (v) => setState(() => _bySupplier = v.first),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: TextField(
            key: const ValueKey('spn-search'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: _bySupplier ? l10n.supSearchHint : l10n.spnSearchHint,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(child: _bySupplier ? _cards(context) : _names(context)),
      ]),
    );
  }

  /// The suppliers, a card each, most recently bought from first.
  Widget _cards(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return ref.watch(supplierCardsProvider).when(
          loading: () => LoadingView(message: l10n.loading),
          error: (e, _) => ErrorStateView(
            message: humanizeApiErrorMessage(l10n, '$e'),
            onRetry: () => ref.invalidate(supplierCardsProvider),
          ),
          data: (all) {
            final cards = all.where(_cardMatches).toList();
            if (cards.isEmpty) return EmptyStateView(icon: Icons.storefront_outlined, title: l10n.supEmpty);
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(supplierCardsProvider),
              child: GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 440,
                  mainAxisExtent: 176,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                ),
                itemCount: cards.length,
                itemBuilder: (_, i) {
                  final c = cards[i];
                  return Card(
                    key: ValueKey('sup-card-${c.id}'),
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        await Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => SupplierDetailScreen(supplierId: c.id)));
                        ref.invalidate(supplierCardsProvider);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.storefront_outlined, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            ),
                            const Icon(Icons.chevron_right),
                          ]),
                          if (c.code != null || c.phone != null)
                            Text([if (c.code != null) c.code!, if (c.phone != null) c.phone!].join(' · '), style: muted),
                          const SizedBox(height: AppSpacing.xs),
                          Text(l10n.supCardStats(c.products, c.purchases, c.units),
                              key: ValueKey('sup-card-stats-${c.id}'), style: theme.textTheme.bodyMedium),
                          Text(c.lastAt == null ? l10n.supNoPurchases : l10n.supLastAt(DateFormat('y/MM/dd').format(c.lastAt!)),
                              style: muted),
                          const Spacer(),
                          if (c.top.isNotEmpty)
                            Text(l10n.supTop(c.top.join('、')),
                                maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
  }

  /// What each supplier calls each product, one by one.
  Widget _names(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(_supplierNamesProvider);
    return async.when(
            loading: () => LoadingView(message: l10n.loading),
            error: (e, _) => ErrorStateView(
              message: humanizeApiErrorMessage(l10n, '$e'),
              onRetry: () => ref.invalidate(_supplierNamesProvider),
            ),
            data: (all) {
              final rows = all.where(_matches).toList();
              if (rows.isEmpty) {
                return EmptyStateView(icon: Icons.translate, title: l10n.spnEmpty, message: l10n.spnEmptyBody);
              }
              final bySupplier = <String, List<SupplierProductName>>{};
              for (final r in rows) {
                bySupplier.putIfAbsent(r.supplierDisplayName, () => []).add(r);
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(_supplierNamesProvider),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    for (final e in bySupplier.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
                        child: Text(e.key, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      Card(
                        child: Column(children: [
                          for (final n in e.value)
                            ListTile(
                              key: ValueKey('spn-${n.supplierId}-${n.productId}'),
                              title: Text('「${n.supplierName}」', maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                [
                                  if (n.supplierCode != null) n.supplierCode!,
                                  '→ ${n.productName ?? ''}',
                                  if (n.janCode != null) n.janCode!,
                                ].join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(fontFamily: AppFonts.mono),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: n.productId == null
                                  ? null
                                  : () => Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => ProductDetailScreen(productId: n.productId!))),
                            ),
                        ]),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
  }
}
