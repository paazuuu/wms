import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/purchase_request_repository.dart';
import '../domain/purchase_request.dart';
import 'purchase_request_screen.dart';

/// 入荷希望リスト (0140, 0205): the wishes from downstream — each list an end
/// customer's (or our own plan), by when — and the summary of the open
/// ones by product, against the stock.
class PurchaseRequestsScreen extends ConsumerStatefulWidget {
  const PurchaseRequestsScreen({super.key});

  @override
  ConsumerState<PurchaseRequestsScreen> createState() => _PurchaseRequestsScreenState();
}

class _PurchaseRequestsScreenState extends ConsumerState<PurchaseRequestsScreen> {
  bool _showClosed = false;

  /// まとめ: whose stock it is weighed against (null: every warehouse).
  int? _warehouseId;
  bool _shortOnly = false;
  final Set<String> _open = {};

  Future<void> _openList({int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PurchaseRequestScreen(requestId: id)));
    ref.invalidate(purchaseRequestsProvider);
    ref.invalidate(wishSummaryProvider);
  }

  Future<void> _remove(PurchaseRequest r) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.prRemoveQ(r.number)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('pr-remove-ok'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.actionDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await ref.read(purchaseRequestRepositoryProvider).remove(r.id);
    if (!mounted) return;
    if (res case ApiFailure(:final message)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
    ref.invalidate(purchaseRequestsProvider);
    ref.invalidate(wishSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.featPurchaseRequest),
          bottom: TabBar(tabs: [
            Tab(key: const ValueKey('wl-tab-lists'), text: l10n.wlTabLists),
            Tab(key: const ValueKey('wl-tab-summary'), text: l10n.wlTabSummary),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('pr-new'),
          onPressed: () => _openList(),
          icon: const Icon(Icons.add),
          label: Text(l10n.prNew),
        ),
        body: TabBarView(children: [_lists(context), _summary(context)]),
      ),
    );
  }

  Widget _lists(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final async = ref.watch(purchaseRequestsProvider);
    final fmt = DateFormat('y/MM/dd');
    return async.when(
      loading: () => LoadingView(message: l10n.loading),
      error: (e, _) => ErrorStateView(
        message: humanizeApiErrorMessage(l10n, '$e'),
        onRetry: () => ref.invalidate(purchaseRequestsProvider),
      ),
      data: (all) {
        final rows = [for (final r in all) if (_showClosed || !r.closed) r];
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
          children: [
            Text(l10n.wlIntro, style: muted),
            const SizedBox(height: AppSpacing.sm),
            FilterChip(
              key: const ValueKey('wl-show-closed'),
              label: Text(l10n.wlShowClosed(all.where((r) => r.closed).length)),
              selected: _showClosed,
              onSelected: (v) => setState(() => _showClosed = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (rows.isEmpty) Text(l10n.prEmpty, key: const ValueKey('pr-empty'), style: muted),
            for (final r in rows)
              Card(
                key: ValueKey('pr-list-${r.id}'),
                child: ListTile(
                  title: Text(
                    [r.customerName ?? r.title ?? l10n.wlNoCustomer, if (r.customerName != null && r.title != null) r.title!]
                        .join('  '),
                    style: theme.textTheme.titleSmall?.copyWith(
                        decoration: r.closed ? TextDecoration.lineThrough : null, color: r.closed ? scheme.onSurfaceVariant : null),
                  ),
                  subtitle: Text(
                    [
                      r.number,
                      r.wantedBy == null ? l10n.wlWantedNone : l10n.wlWantedByIs(fmt.format(r.wantedBy!)),
                      l10n.obSummary(r.lineCount, r.units),
                      if (r.fileName != null) l10n.wlFileBadge(r.fileName!),
                      if (r.closed) l10n.wlClosedBadge,
                    ].join(' · '),
                    style: muted,
                  ),
                  onTap: () => _openList(id: r.id),
                  trailing: IconButton(
                    key: ValueKey('pr-remove-${r.id}'),
                    tooltip: l10n.actionDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(r),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _summary(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final warehouses = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const [];
    final async = ref.watch(wishSummaryProvider(_warehouseId));
    final fmt = DateFormat('y/MM/dd');
    return async.when(
      loading: () => LoadingView(message: l10n.loading),
      error: (e, _) => ErrorStateView(
        message: humanizeApiErrorMessage(l10n, '$e'),
        onRetry: () => ref.invalidate(wishSummaryProvider(_warehouseId)),
      ),
      data: (all) {
        final rows = [for (final s in all) if (!_shortOnly || s.short > 0) s];
        final shortCount = all.where((s) => s.short > 0).length;
        return ListView(
          key: const ValueKey('wl-summary'),
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
          children: [
            Text(l10n.wlSummaryIntro, style: muted),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
              DropdownButton<int?>(
                key: const ValueKey('wl-warehouse'),
                value: _warehouseId,
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text(l10n.ofUdAllWarehouses)),
                  for (final w in warehouses) DropdownMenuItem<int?>(value: w.id, child: Text(w.name)),
                ],
                onChanged: (v) => setState(() => _warehouseId = v),
              ),
              FilterChip(
                key: const ValueKey('wl-short-only'),
                label: Text(l10n.wlShortOnly(shortCount)),
                selected: _shortOnly,
                onSelected: (v) => setState(() => _shortOnly = v),
              ),
              Text(l10n.wlSummaryTotals(all.length, all.fold(0, (a, s) => a + s.wanted), shortCount),
                  key: const ValueKey('wl-totals'), style: theme.textTheme.titleSmall),
            ]),
            const SizedBox(height: AppSpacing.sm),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(l10n.wlSummaryEmpty, key: const ValueKey('wl-summary-empty'), style: muted),
              ),
            for (final s in rows) _summaryCard(context, s, fmt),
          ],
        );
      },
    );
  }

  Widget _summaryCard(BuildContext context, WishSummary s, DateFormat fmt) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final key = '${s.productId ?? s.jan ?? s.name}';
    final open = _open.contains(key);
    return Card(
      key: ValueKey('wl-item-$key'),
      child: InkWell(
        onTap: () => setState(() => open ? _open.remove(key) : _open.add(key)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, style: theme.textTheme.titleSmall),
                  Text([if (s.maker != null) s.maker!, if (s.jan != null) 'JAN ${s.jan}', if (s.sku != null) s.sku!].join(' · '),
                      style: muted),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(l10n.wlWanted(s.wanted), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text(l10n.obStockKeepLine(s.onHand, s.kept, s.free), style: muted),
                Text(
                  s.short > 0 ? l10n.wlShort(s.short) : l10n.wlEnough,
                  key: ValueKey('wl-short-$key'),
                  style: theme.textTheme.labelLarge?.copyWith(color: s.short > 0 ? scheme.error : scheme.success),
                ),
              ]),
              Icon(open ? Icons.expand_less : Icons.expand_more, color: scheme.onSurfaceVariant),
            ]),
            Text(
              [
                l10n.wlCustomers(s.wishes.length),
                if (s.firstWantedBy != null) l10n.wlFirstWanted(fmt.format(s.firstWantedBy!)),
              ].join(' · '),
              style: muted,
            ),
            if (open) ...[
              const Divider(),
              for (final w in s.wishes)
                InkWell(
                  key: ValueKey('wl-wish-$key-${w.requestId}'),
                  onTap: () => _openList(id: w.requestId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text(w.customer ?? l10n.wlNoCustomer, style: theme.textTheme.bodyMedium)),
                      Text(w.wantedBy == null ? l10n.wlWantedNone : fmt.format(w.wantedBy!), style: muted),
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(width: 72, child: Text('× ${w.quantity}', textAlign: TextAlign.end, style: theme.textTheme.titleSmall)),
                      const SizedBox(width: AppSpacing.sm),
                      Text(w.number ?? '', style: muted),
                      Icon(Icons.chevron_right, size: 18, color: scheme.primary),
                    ]),
                  ),
                ),
            ],
          ]),
        ),
      ),
    );
  }
}
