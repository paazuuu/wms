import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../delivery/presentation/reconciliation_screen.dart';
import '../../delivery/presentation/stock_ledger_screen.dart';
import '../../picking_ops/presentation/pick_list_detail_screen.dart';
import '../../shipment/presentation/shipment_detail_screen.dart';
import '../../transfers/presentation/transfer_detail_screen.dart';
import '../application/search_providers.dart';
import '../domain/search_result.dart';

/// Cross-entity search (spec §23): one field, results across products,
/// deliveries, shipments, pick lists and transfers. Purchase/sales orders,
/// suppliers and customers stay out of scope — they're still InventorOS
/// records, not something this app's own database can search.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // searchQueryProvider isn't scoped to this screen's lifetime, so without
    // this a query left over from a previous visit would drive the results
    // while the freshly-built TextField shows empty — reset on every entry.
    Future.microtask(() {
      if (mounted) ref.read(searchQueryProvider.notifier).state = '';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(SearchResult r) {
    final Widget screen;
    switch (r.kind) {
      case SearchResultKind.stock:
        screen = StockLedgerScreen(janCode: r.janCode ?? r.id, productName: r.title);
      case SearchResultKind.delivery:
        screen = ReconciliationScreen(planId: int.parse(r.id));
      case SearchResultKind.shipment:
        screen = ShipmentDetailScreen(shipmentId: int.parse(r.id));
      case SearchResultKind.pickList:
        screen = PickListDetailScreen(pickListId: int.parse(r.id));
      case SearchResultKind.transfer:
        screen = TransferDetailScreen(transferId: int.parse(r.id));
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(searchQueryProvider);
    final async = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
          onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              },
            ),
        ],
      ),
      body: query.isEmpty
          ? EmptyStateView(icon: Icons.search, title: l10n.searchNoQuery)
          : async.when(
              loading: () => LoadingView(message: l10n.loading),
              error: (e, _) => ErrorStateView(
                message: '$e',
                onRetry: () => ref.invalidate(searchResultsProvider),
              ),
              data: (results) {
                if (results.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.search_off,
                    title: l10n.searchEmpty,
                    message: l10n.searchEmptyBody,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _ResultCard(
                    result: results[i],
                    onTap: () => _open(results[i]),
                  ),
                );
              },
            ),
    );
  }
}

({IconData icon, String label}) _kindUi(AppLocalizations l10n, SearchResultKind kind) =>
    switch (kind) {
      SearchResultKind.stock => (
          icon: Icons.inventory_2_outlined,
          label: l10n.searchKindStock,
        ),
      SearchResultKind.delivery => (
          icon: Icons.rule_folder_outlined,
          label: l10n.searchKindDelivery,
        ),
      SearchResultKind.shipment => (
          icon: Icons.outbox_outlined,
          label: l10n.searchKindShipment,
        ),
      SearchResultKind.pickList => (
          icon: Icons.shopping_cart_checkout_outlined,
          label: l10n.searchKindPickList,
        ),
      SearchResultKind.transfer => (
          icon: Icons.compare_arrows,
          label: l10n.searchKindTransfer,
        ),
    };

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = _kindUi(l10n, result.kind);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.surfaceContainerHigh,
                child: Icon(ui.icon, size: 18, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${ui.label}'
                      '${result.subtitle != null && result.subtitle!.isNotEmpty ? ' · ${result.subtitle}' : ''}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
