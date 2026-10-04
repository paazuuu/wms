import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/product_name.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/application/product_providers.dart';
import '../application/price_book_providers.dart';
import '../domain/price_book.dart';
import 'price_book_thumb.dart';

String _yen(double v) => '¥${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';

/// 価格台帳から取り込む (0129): the price book items not in 商品ライブラリー
/// yet — what suppliers quoted that we have not decided to buy — to choose
/// from, one, some or all, and take in (`price_book_to_products`): each a
/// new product, or linked to the one with its JAN. An item without a JAN or
/// a maker cannot become a product and is shown so.
class PriceBookPickScreen extends ConsumerStatefulWidget {
  const PriceBookPickScreen({super.key});

  @override
  ConsumerState<PriceBookPickScreen> createState() => _PriceBookPickScreenState();
}

class _PriceBookPickScreenState extends ConsumerState<PriceBookPickScreen> {
  final Set<int> _chosen = {};
  String _query = '';
  bool _busy = false;

  static bool _canTake(PriceBookItem i) => (i.janCode ?? '').isNotEmpty && (i.maker ?? '').trim().isNotEmpty;

  bool _matches(PriceBookItem i) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [i.name, i.maker, i.itemCode, i.janCode, for (final t in i.terms) t.theirName]
        .any((v) => (v ?? '').toLowerCase().contains(q));
  }

  Future<void> _take() async {
    final l10n = AppLocalizations.of(context);
    final ids = _chosen.toList()..sort();
    if (ids.isEmpty) return;
    setState(() => _busy = true);
    final r = await ref.read(priceBookRepositoryProvider).toProducts(ids);
    if (!mounted) return;
    setState(() => _busy = false);
    final messenger = ScaffoldMessenger.of(context);
    switch (r) {
      case ApiSuccess(:final data):
        _chosen.clear();
        ref.invalidate(priceBookListProvider);
        ref.invalidate(productListProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.clToMasterDone(data.created, data.linked, data.skipped))));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(priceBookListProvider);
    final waiting = [for (final i in async.valueOrNull ?? const <PriceBookItem>[]) if (!i.inMaster) i];
    final shown = [for (final i in waiting) if (_matches(i)) i];
    final takeable = [for (final i in shown) if (_canTake(i)) i];
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pkTitle)),
      bottomNavigationBar: waiting.isEmpty
          ? null
          : Material(
              elevation: 8,
              color: theme.colorScheme.surfaceContainerHigh,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        key: const ValueKey('pk-select-all'),
                        onPressed: _busy ? null : () => setState(() => _chosen.addAll([for (final i in takeable) i.id])),
                        icon: const Icon(Icons.select_all, size: 18),
                        label: Text(l10n.pkSelectAll(takeable.length)),
                      ),
                      TextButton.icon(
                        key: const ValueKey('pk-clear'),
                        onPressed: _busy || _chosen.isEmpty ? null : () => setState(_chosen.clear),
                        icon: const Icon(Icons.deselect, size: 18),
                        label: Text(l10n.lcClear),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('pk-import'),
                        onPressed: _busy || _chosen.isEmpty ? null : _take,
                        icon: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.inventory_2_outlined, size: 18),
                        label: Text(l10n.pkImport(_chosen.length)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: humanizeApiErrorMessage(l10n, '$e'),
          onRetry: () => ref.invalidate(priceBookListProvider),
        ),
        data: (_) => waiting.isEmpty
            ? EmptyStateView(icon: Icons.check_circle_outline, title: l10n.pkEmpty, message: l10n.pkEmptyBody)
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
                children: [
                  Text(l10n.pkIntro, key: const ValueKey('pk-intro'), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const ValueKey('pk-search'),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.clSearchHint,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final i in shown)
                    Card(
                      child: CheckboxListTile(
                        key: ValueKey('pk-${i.id}'),
                        value: _chosen.contains(i.id),
                        onChanged: _busy || !_canTake(i)
                            ? null
                            : (on) => setState(() => on == true ? _chosen.add(i.id) : _chosen.remove(i.id)),
                        secondary: PriceBookThumb(item: i, size: 48),
                        title: Text(widenKana(i.name)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            [
                              if (i.maker != null) widenKana(i.maker!),
                              if (i.itemCode != null) widenKana(i.itemCode!),
                              if (i.janCode != null) i.janCode!,
                            ].join(' · '),
                            style: muted,
                          ),
                          // Who quoted it and for how much, cheapest first.
                          for (final t in i.terms.take(3))
                            Text(
                              [
                                t.where == null ? t.partnerName : '${t.partnerName}（${t.where}）',
                                if (t.unitPrice != null) _yen(t.unitPrice!),
                                if (t.discountRate != null)
                                  l10n.quoteRate('${(t.discountRate! * 100).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%'),
                              ].join('　'),
                              style: theme.textTheme.bodySmall,
                            ),
                          if (!_canTake(i))
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: StatusPill(tone: StatusTone.warning, label: l10n.pkBlocked, dense: true),
                            ),
                        ]),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
