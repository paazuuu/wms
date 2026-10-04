import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/product_name.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/domain/product.dart' show ProductLifecycle;
import '../../product/presentation/product_lifecycle_ui.dart';
import '../../product_library/presentation/product_thumb.dart';
import '../application/catalog_providers.dart';
import '../domain/catalog.dart';

/// マスタから取り込む (0125): the master products not in 商品ライブラリー yet,
/// to choose from and copy in — spec, pictures and each supplier's name and
/// terms. Only products missing from the library are listed, so nothing
/// already there is overwritten.
class MasterImportScreen extends ConsumerStatefulWidget {
  const MasterImportScreen({super.key});

  @override
  ConsumerState<MasterImportScreen> createState() => _MasterImportScreenState();
}

class _MasterImportScreenState extends ConsumerState<MasterImportScreen> {
  final Set<int> _chosen = {};
  bool _busy = false;

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final ids = _chosen.toList()..sort();
    if (ids.isEmpty) return;
    setState(() => _busy = true);
    final r = await ref.read(catalogRepositoryProvider).fromMaster(ids);
    if (!mounted) return;
    setState(() => _busy = false);
    final messenger = ScaffoldMessenger.of(context);
    switch (r) {
      case ApiSuccess(:final data):
        ref.invalidate(catalogListProvider);
        ref.invalidate(masterCandidatesProvider);
        _chosen.clear();
        messenger.showSnackBar(SnackBar(content: Text(l10n.cfmDone(data.created, data.terms))));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(masterCandidatesProvider);
    final all = async.valueOrNull ?? const <MasterCandidate>[];
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cfmTitle)),
      bottomNavigationBar: all.isEmpty
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
                        key: const ValueKey('cfm-select-all'),
                        onPressed: _busy ? null : () => setState(() => _chosen.addAll([for (final c in all) c.id])),
                        icon: const Icon(Icons.select_all, size: 18),
                        label: Text(l10n.cfmSelectAll(all.length)),
                      ),
                      TextButton.icon(
                        key: const ValueKey('cfm-clear'),
                        onPressed: _busy || _chosen.isEmpty ? null : () => setState(_chosen.clear),
                        icon: const Icon(Icons.deselect, size: 18),
                        label: Text(l10n.lcClear),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('cfm-import'),
                        onPressed: _busy || _chosen.isEmpty ? null : _import,
                        icon: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.move_down_outlined, size: 18),
                        label: Text(l10n.cfmImport(_chosen.length)),
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
          onRetry: () => ref.invalidate(masterCandidatesProvider),
        ),
        data: (rows) => rows.isEmpty
            ? EmptyStateView(icon: Icons.check_circle_outline, title: l10n.cfmEmpty, message: l10n.cfmEmptyBody)
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
                children: [
                  Text(l10n.cfmIntro, key: const ValueKey('cfm-intro'), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  for (final c in rows)
                    Card(
                      child: CheckboxListTile(
                        key: ValueKey('cfm-${c.id}'),
                        value: _chosen.contains(c.id),
                        onChanged: _busy
                            ? null
                            : (on) => setState(() => on == true ? _chosen.add(c.id) : _chosen.remove(c.id)),
                        secondary: ProductThumb(productId: c.id, janCode: c.janCode, productName: c.name, size: 48, openOnTap: false),
                        title: Text(widenKana(c.name)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            [
                              if (c.maker != null) widenKana(c.maker!),
                              if (c.sku != null) widenKana(c.sku!),
                              if (c.janCode != null) c.janCode!,
                            ].join(' · '),
                            style: muted,
                          ),
                          Wrap(spacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            if (c.supplierCount > 0) Text(l10n.cfmSuppliers(c.supplierCount), style: muted),
                            if (c.lifecycle != ProductLifecycle.active) LifecyclePill(lifecycle: c.lifecycle),
                          ]),
                        ]),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
