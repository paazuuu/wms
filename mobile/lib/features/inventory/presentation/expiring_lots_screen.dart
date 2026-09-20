import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/domain/product_lot.dart';
import '../../product/presentation/product_detail_screen.dart';
import '../application/inventory_providers.dart';

/// Lots running out of time (§4, `expiring_lots`).
///
/// The list a warehouse works through before stock becomes unsellable. Already
/// expired lots are at the top rather than filtered out: an expired lot is a
/// decision someone owes, and hiding it would be the one way to make it worse.
///
/// Not warehouse-scoped, because a lot belongs to a product and not to a
/// building — the server says so too. It becomes a per-warehouse question once
/// stock rows carry `lot_id`.
class ExpiringLotsScreen extends ConsumerWidget {
  const ExpiringLotsScreen({super.key});

  static const _horizons = [7, 30, 90, 180];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final days = ref.watch(expiryHorizonProvider);
    final async = ref.watch(expiringLotsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expiryTitle),
        actions: [
          // The horizon is the one control this screen needs: "this week" and
          // "this quarter" are different jobs.
          PopupMenuButton<int>(
            initialValue: days,
            tooltip: l10n.expiryHorizon(days),
            onSelected: (v) =>
                ref.read(expiryHorizonProvider.notifier).state = v,
            itemBuilder: (_) => [
              for (final d in _horizons)
                PopupMenuItem(value: d, child: Text(l10n.expiryHorizon(d))),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(children: [
                Text(l10n.expiryHorizon(days), style: theme.textTheme.labelLarge),
                const Icon(Icons.arrow_drop_down),
              ]),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(expiringLotsProvider),
        ),
        data: (lots) {
          if (lots.isEmpty) {
            return EmptyStateView(
              icon: Icons.event_available_outlined,
              title: l10n.expiryEmpty,
              message: l10n.expiryEmptyBody,
            );
          }
          final expired = lots.where((l) => l.isExpired).length;
          final soon = lots.length - expired;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(expiringLotsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: lots.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => i == 0
                  ? _Summary(expired: expired, soon: soon)
                  : _LotCard(lot: lots[i - 1]),
            ),
          );
        },
      ),
    );
  }
}

/// How much of each kind is on the list, so the size of the problem is legible
/// before scrolling it.
class _Summary extends StatelessWidget {
  const _Summary({required this.expired, required this.soon});

  final int expired;
  final int soon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          if (expired > 0)
            StatusPill(
                tone: StatusTone.danger, label: l10n.expiryExpiredCount(expired)),
          if (soon > 0)
            StatusPill(
                tone: StatusTone.warning, label: l10n.expirySoonCount(soon)),
        ],
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  const _LotCard({required this.lot});

  final ExpiringLot lot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final df = DateFormat('yyyy-MM-dd');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Straight to the product, which is where its other lots, its codes and
        // its stock position are.
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: lot.productId),
        )),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lot.productName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [
                        lot.lotCode,
                        if (lot.expiryDate != null)
                          l10n.productLotExpiryOn(df.format(lot.expiryDate!)),
                        if (lot.serialCount > 0)
                          l10n.productLotSerialCount(lot.serialCount),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (lot.janCode != null) ...[
                      const SizedBox(height: 2),
                      Text(lot.janCode!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: AppFonts.mono,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              lot.isExpired
                  ? StatusPill(
                      tone: StatusTone.danger,
                      label: l10n.productLotExpired,
                      dense: true)
                  : StatusPill(
                      tone: (lot.daysToExpiry ?? 999) <= 7
                          ? StatusTone.danger
                          : StatusTone.warning,
                      label: l10n.productLotDaysLeft(lot.daysToExpiry ?? 0),
                      dense: true,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
