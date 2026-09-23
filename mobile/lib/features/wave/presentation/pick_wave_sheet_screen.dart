import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/pick_wave_providers.dart';
import '../domain/pick_wave.dart';

/// The whole point of a wave (§15, 0077): one stop per place and parcel, not
/// one line per order. Three orders wanting the same box show here as one
/// row — "R-01-A, lot L-B, take 30" — with which orders those units are for.
class PickWaveSheetScreen extends ConsumerWidget {
  const PickWaveSheetScreen({super.key, required this.waveId});

  final int waveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(wavePickPlanProvider(waveId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.waveSheetTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(wavePickPlanProvider(waveId)),
        ),
        data: (plan) {
          if (plan.stops.isEmpty && plan.short.isEmpty) {
            return EmptyStateView(
              icon: Icons.list_alt_outlined,
              title: l10n.waveSheetEmpty,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(wavePickPlanProvider(waveId)),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(l10n.waveSheetTotalUnits(plan.totalUnits),
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                for (final stop in plan.stops) ...[
                  _StopCard(stop: stop),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (plan.hasShortfall) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.waveShortfallTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final s in plan.short) _ShortRow(short: s),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({required this.stop});

  final WaveStop stop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final orderCount = stop.lines.map((l) => l.shipmentPlanId).toSet().length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // The place, first — this is a walking route, not a list.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    stop.binCode ?? '—',
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: AppFonts.mono, color: scheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    stop.productName.isNotEmpty ? stop.productName : stop.janCode,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${stop.quantity}',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontFamily: AppFonts.mono, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text(stop.janCode,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: AppFonts.mono, color: scheme.onSurfaceVariant)),
            if (stop.lotCode != null) ...[
              const SizedBox(height: 2),
              Text('L:${stop.lotCode}${stop.expiryDate != null ? ' (${stop.expiryDate})' : ''}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            if (orderCount > 1) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.waveSheetForOrders(orderCount),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShortRow extends StatelessWidget {
  const _ShortRow({required this.short});

  final WaveShort short;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: scheme.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(short.janCode,
                style: theme.textTheme.bodyMedium?.copyWith(fontFamily: AppFonts.mono)),
          ),
          Text(l10n.waveShortfallUnits(short.short),
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
        ],
      ),
    );
  }
}
