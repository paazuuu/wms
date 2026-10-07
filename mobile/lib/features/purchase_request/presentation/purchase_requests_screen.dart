import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../data/purchase_request_repository.dart';
import '../domain/purchase_request.dart';
import 'purchase_request_screen.dart';

/// 入荷希望リスト (0140): the lists kept, newest first; open one to change it
/// or download it again, or start a new one.
class PurchaseRequestsScreen extends ConsumerWidget {
  const PurchaseRequestsScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PurchaseRequestScreen(requestId: id)));
    ref.invalidate(purchaseRequestsProvider);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, PurchaseRequest r) async {
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
    if (ok != true || !context.mounted) return;
    final res = await ref.read(purchaseRequestRepositoryProvider).remove(r.id);
    if (!context.mounted) return;
    if (res case ApiFailure(:final message)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
    ref.invalidate(purchaseRequestsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(purchaseRequestsProvider);
    final fmt = DateFormat('y/MM/dd HH:mm');
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featPurchaseRequest)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('pr-new'),
        onPressed: () => _open(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.prNew),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: humanizeApiErrorMessage(l10n, '$e'),
          onRetry: () => ref.invalidate(purchaseRequestsProvider),
        ),
        data: (rows) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
          children: [
            Text(l10n.prIntro, style: muted),
            const SizedBox(height: AppSpacing.md),
            if (rows.isEmpty) Text(l10n.prEmpty, key: const ValueKey('pr-empty'), style: muted),
            for (final r in rows)
              Card(
                key: ValueKey('pr-list-${r.id}'),
                child: ListTile(
                  title: Text([r.number, if (r.title != null) r.title!].join('  ')),
                  subtitle: Text(
                    [
                      r.supplierName ?? l10n.prSupplierNone,
                      l10n.obSummary(r.lineCount, r.units),
                      if (r.updatedAt != null) fmt.format(r.updatedAt!),
                      if (r.createdByName != null) r.createdByName!,
                    ].join(' · '),
                    style: muted,
                  ),
                  onTap: () => _open(context, ref, id: r.id),
                  trailing: IconButton(
                    key: ValueKey('pr-remove-${r.id}'),
                    tooltip: l10n.actionDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(context, ref, r),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
