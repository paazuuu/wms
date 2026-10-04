import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/product_name.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../product_library/application/product_library_providers.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';
import 'product_detail_screen.dart';

String alertReasonLabel(AppLocalizations l10n, ProductAlertReason r) => switch (r) {
      ProductAlertReason.janExists => l10n.alReasonJanExists,
      ProductAlertReason.janInFile => l10n.alReasonJanInFile,
      ProductAlertReason.skuExists => l10n.alReasonSkuExists,
    };

/// 商品ライブラリー's アラート tab (0130): every line a file import kept back
/// because its JAN or 品番 was already registered (or its JAN came twice in
/// the file) — what it said, why, the file and row, and the product it
/// collides with. Alerts are removed for good, chosen ones or all of them;
/// products are never touched from here.
class ProductAlertsTab extends ConsumerStatefulWidget {
  const ProductAlertsTab({super.key});

  @override
  ConsumerState<ProductAlertsTab> createState() => _ProductAlertsTabState();
}

class _ProductAlertsTabState extends ConsumerState<ProductAlertsTab> {
  final Set<int> _chosen = {};
  bool _busy = false;

  Future<void> _delete(List<int>? ids, int count) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.alDeleteQ(count)),
        content: Text(l10n.alDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.actionCancel)),
          FilledButton(
            key: const ValueKey('al-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(d).colorScheme.error,
              foregroundColor: Theme.of(d).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(d, true),
            child: Text(l10n.productDeleteAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(productRepositoryProvider).deleteAlerts(ids);
    if (!mounted) return;
    setState(() => _busy = false);
    final messenger = ScaffoldMessenger.of(context);
    switch (r) {
      case ApiSuccess(:final data):
        _chosen.clear();
        ref.invalidate(productAlertsProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.alDeleted(data))));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canManage = ref.watch(productLibraryCanManageProvider);
    final async = ref.watch(productAlertsProvider);
    final alerts = async.valueOrNull ?? const <ProductAlert>[];

    return async.when(
      loading: () => LoadingView(message: l10n.loading),
      error: (e, _) => ErrorStateView(
        message: humanizeApiErrorMessage(l10n, '$e'),
        onRetry: () => ref.invalidate(productAlertsProvider),
      ),
      data: (_) => alerts.isEmpty
          ? EmptyStateView(icon: Icons.check_circle_outline, title: l10n.alEmpty, message: l10n.alEmptyBody)
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(productAlertsProvider),
              child: ListView(
                key: const ValueKey('al-list'),
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
                children: [
                  Text(l10n.alHint, style: theme.textTheme.bodySmall),
                  if (canManage) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        TextButton.icon(
                          key: const ValueKey('al-select-all'),
                          onPressed: _busy ? null : () => setState(() => _chosen.addAll([for (final a in alerts) a.id])),
                          icon: const Icon(Icons.select_all, size: 18),
                          label: Text(l10n.lcSelectAll(alerts.length)),
                        ),
                        TextButton.icon(
                          key: const ValueKey('al-clear'),
                          onPressed: _busy || _chosen.isEmpty ? null : () => setState(_chosen.clear),
                          icon: const Icon(Icons.deselect, size: 18),
                          label: Text(l10n.lcClear),
                        ),
                        FilledButton.tonalIcon(
                          key: const ValueKey('al-delete-selected'),
                          onPressed: _busy || _chosen.isEmpty ? null : () => _delete(_chosen.toList()..sort(), _chosen.length),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(l10n.alDeleteSelected(_chosen.length)),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('al-delete-all'),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          ),
                          onPressed: _busy ? null : () => _delete(null, alerts.length),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                          label: Text(l10n.alDeleteAll(alerts.length)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  for (final a in alerts)
                    _AlertCard(
                      alert: a,
                      chosen: canManage ? _chosen.contains(a.id) : null,
                      onChosen: (on) => setState(() => on ? _chosen.add(a.id) : _chosen.remove(a.id)),
                    ),
                ],
              ),
            ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.chosen, required this.onChosen});

  final ProductAlert alert;

  /// Null without product.manage.
  final bool? chosen;
  final void Function(bool) onChosen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final a = alert;
    Widget row(String k, String? v) => v == null || v.trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 110, child: Text(k, style: muted)),
              Expanded(child: Text(widenKana(v), style: theme.textTheme.bodyMedium)),
            ]),
          );
    final l = a.line;
    String? s(String key) => l[key] == null ? null : '${l[key]}';
    final attrs = [
      for (final x in (l['attributes'] is List ? l['attributes'] as List : const []).whereType<Map>())
        if ('${x['value'] ?? ''}'.trim().isNotEmpty) '${x['name'] ?? x['key']}: ${x['value']}',
    ];
    return Card(
      key: ValueKey('al-${a.id}'),
      color: chosen == true ? theme.colorScheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (chosen != null)
            Checkbox(key: ValueKey('al-check-${a.id}'), value: chosen, onChanged: (v) => onChosen(v ?? false)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(widenKana(a.name ?? '—'), style: theme.textTheme.titleSmall)),
                StatusPill(tone: StatusTone.warning, label: alertReasonLabel(l10n, a.reason), dense: true),
              ]),
              const SizedBox(height: AppSpacing.xs),
              row(l10n.pdJan, a.janCode),
              row(l10n.pdMaker, a.maker),
              row(l10n.pdCode, a.itemCode),
              row(l10n.pdListPrice, s('list_price')),
              row(l10n.pdUnit, s('unit')),
              if (attrs.isNotEmpty) row(l10n.pdBasics, attrs.join('　')),
              if (a.sourceFile != null || a.rowNo != null)
                row(l10n.citSourceFile, l10n.alFrom(a.sourceFile ?? '—', a.rowNo ?? 0)),
              // The product it collides with.
              if (a.existingName != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.alExisting(widenKana(a.existingName!)),
                    key: ValueKey('al-existing-${a.id}'), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text([if (a.existingMaker != null) a.existingMaker!, if (a.existingSku != null) a.existingSku!].join(' · '),
                    style: muted),
              ],
              if (a.existingProductId case final pid?)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: ValueKey('al-open-${a.id}'),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(productId: pid),
                    )),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(l10n.alOpenExisting),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
