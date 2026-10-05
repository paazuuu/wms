import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/application/product_providers.dart';
import '../../product/domain/supplier_product_name.dart';
import '../../product/presentation/product_detail_screen.dart';

final _supplierNamesProvider = FutureProvider.autoDispose<List<SupplierProductName>>((ref) async {
  final r = await ref.watch(productRepositoryProvider).supplierNames();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// 仕入先商品名 (§38, §40): what every supplier calls our products, kept as
/// they write it, each pointing at one product id. A supplier's Japanese
/// name finds our product here.
class SupplierProductNamesScreen extends ConsumerStatefulWidget {
  const SupplierProductNamesScreen({super.key});

  @override
  ConsumerState<SupplierProductNamesScreen> createState() => _SupplierProductNamesScreenState();
}

class _SupplierProductNamesScreenState extends ConsumerState<SupplierProductNamesScreen> {
  String _query = '';

  bool _matches(SupplierProductName n) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [n.supplierDisplayName, n.supplierName, n.supplierCode, n.productName, n.janCode, n.supplierJanCode, n.supplierMaker]
        .any((v) => (v ?? '').toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(_supplierNamesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featSupplierProductNames)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: TextField(
            key: const ValueKey('spn-search'),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.spnSearchHint),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: async.when(
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
          ),
        ),
      ]),
    );
  }
}
