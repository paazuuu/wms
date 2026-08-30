import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../products/domain/product.dart';
import '../application/tracking_providers.dart';
import '../domain/product_batch.dart';
import '../domain/product_serial.dart';

/// Read-only lot/serial tracing for a single product: two sections listing the
/// product's batches (with quantity and expiry) and serialized units (with a
/// lifecycle status).
class TrackingDetailScreen extends ConsumerWidget {
  const TrackingDetailScreen({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final batches = ref.watch(productBatchesProvider(product.id));
    final serials = ref.watch(productSerialsProvider(product.id));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featLotsSerials)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(productBatchesProvider(product.id));
          ref.invalidate(productSerialsProvider(product.id));
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: theme.textTheme.titleLarge),
                    if (product.sku.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.sku,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFamily: 'FiraCode',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(
                label: l10n.sectionBatches,
                icon: Icons.inventory_2_outlined),
            const SizedBox(height: AppSpacing.sm),
            batches.when(
              data: (items) => items.isEmpty
                  ? _SectionEmpty(message: l10n.noBatches)
                  : Column(
                      children: items
                          .map((b) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md),
                                child: _BatchCard(batch: b),
                              ))
                          .toList(),
                    ),
              loading: () => LoadingView(message: l10n.loadingBatches),
              error: (error, _) => ErrorStateView(
                message: '$error',
                onRetry: () =>
                    ref.invalidate(productBatchesProvider(product.id)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(label: l10n.sectionSerials, icon: Icons.tag_outlined),
            const SizedBox(height: AppSpacing.sm),
            serials.when(
              data: (items) => items.isEmpty
                  ? _SectionEmpty(message: l10n.noSerials)
                  : Column(
                      children: items
                          .map((s) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md),
                                child: _SerialCard(serial: s),
                              ))
                          .toList(),
                    ),
              loading: () => LoadingView(message: l10n.loadingSerials),
              error: (error, _) => ErrorStateView(
                message: '$error',
                onRetry: () =>
                    ref.invalidate(productSerialsProvider(product.id)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({required this.batch});

  final ProductBatch batch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    batch.displayNumber,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontFamily: 'FiraCode'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusPill(
                  tone: batch.isExpired
                      ? StatusTone.danger
                      : StatusTone.success,
                  label: batch.isExpired ? l10n.batchExpired : l10n.batchValid,
                  icon: batch.isExpired
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _Stat(label: l10n.quantity, value: '${batch.quantity}'),
                _Stat(label: l10n.fieldExpiry, value: batch.expiryDate ?? '—'),
              ],
            ),
            if (batch.notes != null && batch.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                batch.notes!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SerialCard extends StatelessWidget {
  const _SerialCard({required this.serial});

  final ProductSerial serial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = serial.status?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.tag_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                serial.displayNumber,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontFamily: 'FiraCode'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (status != null && status.isNotEmpty)
              StatusPill(
                tone: StatusTone.neutral,
                label: status,
                icon: Icons.circle_outlined,
                dense: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontFamily: 'FiraCode'),
          ),
        ],
      ),
    );
  }
}
