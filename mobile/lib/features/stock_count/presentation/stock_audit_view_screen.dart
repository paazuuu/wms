import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/stock_audit_providers.dart';
import '../domain/stock_audit.dart';
import '../domain/stock_audit_item.dart';
import 'stock_audit_status_ui.dart';

/// Read-only stock count view: status, scope, dates, and counted vs. system
/// quantities per line with the resulting discrepancy.
class StockAuditViewScreen extends ConsumerWidget {
  const StockAuditViewScreen({super.key, required this.stockAuditId});

  final int stockAuditId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audit = ref.watch(stockAuditDetailProvider(stockAuditId));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featStockCount)),
      body: audit.when(
        data: (a) => _StockAuditBody(audit: a),
        loading: () => LoadingView(message: l10n.loading),
        error: (error, _) => ErrorStateView(
          message: '$error',
          onRetry: () => ref.invalidate(stockAuditDetailProvider(stockAuditId)),
        ),
      ),
    );
  }
}

class _StockAuditBody extends StatelessWidget {
  const _StockAuditBody({required this.audit});

  final StockAudit audit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final status = StockAuditStatusUi.of(l10n, audit);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusAvatar(tone: status.tone, icon: status.icon),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Text(
                        audit.auditNumber,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontFamily: 'FiraCode'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                StatusPill(
                  tone: status.tone,
                  label: status.label,
                  icon: status.icon,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _InfoRow(label: l10n.fieldName, value: audit.name ?? '—'),
                _InfoRow(label: l10n.fieldType, value: audit.auditType ?? '—'),
                _InfoRow(
                    label: l10n.fieldLocation,
                    value: audit.locationName ?? l10n.filterAll),
                _InfoRow(label: l10n.fieldStarted, value: audit.startedAt ?? '—'),
                _InfoRow(
                    label: l10n.statusCompleted,
                    value: audit.completedAt ?? '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.fieldCountedLines,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (audit.items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(l10n.noCountedLines,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          )
        else
          ...audit.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _LineCard(item: item),
              )),
        if (audit.notes != null && audit.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.fieldNotes,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(audit.notes!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.item});

  final StockAuditItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final diff = item.effectiveDiscrepancy;
    final (tone, label, icon) = _discrepancyBadge(l10n, item);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName.isNotEmpty
                            ? item.productName
                            : l10n.productNumber(item.productId),
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.sku.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.sku,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFamily: 'FiraCode',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                StatusPill(tone: tone, label: label, icon: icon, dense: true),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _Stat(label: l10n.fieldSystem, value: '${item.systemQuantity}'),
                _Stat(
                    label: l10n.fieldCounted,
                    value: item.isCounted ? '${item.countedQuantity}' : '—'),
                _Stat(
                    label: l10n.fieldDiscrepancy,
                    value: diff > 0 ? '+$diff' : '$diff'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (StatusTone, String, IconData) _discrepancyBadge(
      AppLocalizations l10n, StockAuditItem item) {
    if (!item.isCounted) {
      return (StatusTone.neutral, l10n.fieldUncounted, Icons.hourglass_bottom);
    }
    final diff = item.effectiveDiscrepancy;
    if (diff == 0) {
      return (StatusTone.success, l10n.fieldMatch, Icons.check_circle_outline);
    }
    return (StatusTone.warning, diff > 0 ? '+$diff' : '$diff',
        Icons.warning_amber_outlined);
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
