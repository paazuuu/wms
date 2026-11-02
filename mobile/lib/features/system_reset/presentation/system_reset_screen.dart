import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../master_import/data/master_import_repository.dart' show masterImportsProvider;
import '../../payments/data/payments_repository.dart' show paymentsProvider;
import '../../price_book/application/price_book_providers.dart' show priceBookListProvider;
import '../../product/application/product_providers.dart' show productListProvider;
import '../../stock_import/data/stock_import_repository.dart' show awaitingImportsProvider, pendingInspectionProvider;
import '../data/system_reset_repository.dart';

/// The word typed to say one means it.
const resetWord = '初期化';

/// 管理 → システムの初期化 (0175): the environment emptied of what was done
/// in it, to test again from nothing or before handing it over. The system
/// administrator's only. What goes, by kind, is shown with how much there is
/// first; users, warehouses, settings, keys and catalogs always stay.
class SystemResetScreen extends ConsumerStatefulWidget {
  const SystemResetScreen({super.key});

  @override
  ConsumerState<SystemResetScreen> createState() => _SystemResetScreenState();
}

class _SystemResetScreenState extends ConsumerState<SystemResetScreen> {
  ResetOptions _options = const ResetOptions();
  final _word = TextEditingController();
  bool _busy = false;
  ResetResult? _done;

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.srConfirmTitle),
        content: Text(l10n.srConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(
            key: const ValueKey('sr-confirm'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.srRun),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(systemResetRepositoryProvider).reset(_word.text.trim(), _options);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        setState(() {
          _done = data;
          _word.clear();
        });
        // What other screens hold is read again.
        for (final p in [
          productListProvider, priceBookListProvider, masterImportsProvider, pendingInspectionProvider,
          awaitingImportsProvider, systemResetPreviewProvider,
        ]) {
          ref.invalidate(p);
        }
        ref.invalidate(paymentsProvider);
      case ApiFailure(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final may = ref.watch(authControllerProvider).user?.hasPermission('system.reset') ?? false;
    if (!may) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.featSystemReset)),
        body: Center(child: Text(l10n.srNoPermission, key: const ValueKey('sr-no-permission'))),
      );
    }
    final async = ref.watch(systemResetPreviewProvider);
    final n = NumberFormat.decimalPattern();
    String count(ResetCounts c, List<String> keys) => n.format(keys.fold<int>(0, (s, k) => s + (c[k] ?? 0)));

    Widget group({
      required Key key,
      required String title,
      required String detail,
      bool? value,
      ValueChanged<bool>? onChanged,
    }) =>
        Card(
          key: key,
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: value == null
              ? ListTile(
                  leading: Icon(Icons.delete_sweep_outlined, color: scheme.error),
                  title: Text(title),
                  subtitle: Text(detail, style: muted),
                )
              : CheckboxListTile(
                  value: value,
                  onChanged: _busy ? null : (v) => onChanged!(v ?? false),
                  title: Text(title),
                  subtitle: Text(detail, style: muted),
                ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featSystemReset)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(l10n.srIntro, style: TextStyle(color: scheme.onErrorContainer))),
              ]),
            ),
          ),
          if (_done case final d?)
            Card(
              key: const ValueKey('sr-done'),
              color: scheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(l10n.srDone),
                subtitle: Text(l10n.srDoneDetail(
                  n.format(d.before['imports'] ?? 0),
                  n.format(d.before['products'] ?? 0),
                  d.filesRemoved,
                  d.filesFailed,
                )),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          ...async.when(
            loading: () => const [LoadingView()],
            error: (e, _) => [
              ErrorStateView(
                  message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(systemResetPreviewProvider)),
            ],
            data: (c) => [
              Text(l10n.srAlways, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              group(
                key: const ValueKey('sr-done-work'),
                title: l10n.srWork,
                detail: l10n.srWorkDetail(
                  count(c, ['imports']),
                  count(c, ['documents']),
                  count(c, ['proofs']),
                  count(c, ['deliveries', 'inspections', 'orders']),
                  count(c, ['stock_levels']),
                  count(c, ['movements']),
                  count(c, ['files']),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.srChoose, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              group(
                key: const ValueKey('sr-products'),
                title: l10n.srProducts,
                detail: l10n.srProductsDetail(count(c, ['products']), count(c, ['price_book'])),
                value: _options.products,
                onChanged: (v) => setState(() => _options = _options.copyWith(products: v)),
              ),
              group(
                key: const ValueKey('sr-suppliers'),
                title: l10n.srSuppliers,
                detail: l10n.srSuppliersDetail(count(c, ['suppliers']), count(c, ['learned'])),
                value: _options.suppliers,
                onChanged: (v) => setState(() => _options = _options.copyWith(suppliers: v)),
              ),
              group(
                key: const ValueKey('sr-lookups'),
                title: l10n.srLookups,
                detail: l10n.srLookupsDetail(count(c, ['lookups'])),
                value: _options.lookups,
                onChanged: (v) => setState(() => _options = _options.copyWith(lookups: v)),
              ),
              group(
                key: const ValueKey('sr-logs'),
                title: l10n.srLogs,
                detail: l10n.srLogsDetail(count(c, ['audit']), count(c, ['ai_calls'])),
                value: _options.logs,
                onChanged: (v) => setState(() => _options = _options.copyWith(logs: v)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.srKept, style: muted),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const ValueKey('sr-word'),
            controller: _word,
            enabled: !_busy,
            decoration: InputDecoration(labelText: l10n.srTypeWord(resetWord), border: const OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const ValueKey('sr-run'),
            style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
            onPressed: _busy || _word.text.trim() != resetWord ? null : _reset,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.restart_alt),
            label: Text(l10n.srRun),
          ),
        ],
      ),
    );
  }
}
