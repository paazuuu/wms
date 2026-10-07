import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../product/application/product_providers.dart';
import '../data/master_import_repository.dart';
import '../domain/master_import.dart';
import 'master_import_labels.dart';
import 'master_import_screen.dart';

/// ファイルから商品・在庫登録 (0138): start one, or look back at earlier ones —
/// where each got to, what stopped it, its files to download, and for each
/// line the stock it found, what was added and what it came to.
class MasterImportsScreen extends ConsumerWidget {
  const MasterImportsScreen({super.key, this.saveFile});

  final SaveBytes? saveFile;

  static StatusTone _tone(MasterImportStatus s) => switch (s) {
        MasterImportStatus.stockDone => StatusTone.success,
        MasterImportStatus.masterDone => StatusTone.info,
        MasterImportStatus.stopped => StatusTone.danger,
        MasterImportStatus.cancelled => StatusTone.neutral,
        MasterImportStatus.reading => StatusTone.warning,
      };

  Future<void> _open(BuildContext context, WidgetRef ref, {int? resume}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MasterImportScreen(resumeImportId: resume)));
    ref.invalidate(masterImportsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final canManage = ref.watch(authControllerProvider).user?.hasPermission('product.manage') ?? false;
    final async = ref.watch(masterImportsProvider);
    final fmt = DateFormat('y/MM/dd HH:mm');
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featMasterStockImport)),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              key: const ValueKey('mi-new'),
              onPressed: () => _open(context, ref),
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(l10n.miPick),
            )
          : null,
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: humanizeApiErrorMessage(l10n, '$e'),
          onRetry: () => ref.invalidate(masterImportsProvider),
        ),
        data: (rows) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(masterImportsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
            children: [
              Text(l10n.miIntro, style: muted),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.miHistory, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (rows.isEmpty) Text(l10n.miHistoryEmpty, key: const ValueKey('mi-history-empty'), style: muted),
              for (final m in rows)
                Card(
                  key: ValueKey('mi-row-${m.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text(m.originalName ?? '#${m.id}', style: theme.textTheme.titleSmall),
                        ),
                        StatusPill(tone: _tone(m.status), label: masterStatusLabel(l10n, m.status), dense: true),
                      ]),
                      Text(
                        [
                          if (m.createdAt != null) fmt.format(m.createdAt!),
                          if (m.createdByName != null) m.createdByName!,
                          l10n.miLinesCount(m.lineCount),
                          if (m.supplierName != null) m.supplierName!,
                          if (m.warehouseName != null) m.warehouseName!,
                        ].join(' · '),
                        style: muted,
                      ),
                      if (m.status == MasterImportStatus.masterDone || m.status == MasterImportStatus.stockDone)
                        Text(l10n.miMasterSummary(m.created, m.updated), style: theme.textTheme.bodySmall),
                      if (m.status == MasterImportStatus.stockDone)
                        Text(l10n.miStockDone(m.stockLines, m.stockAdded), style: theme.textTheme.bodySmall),
                      if (m.status == MasterImportStatus.stopped && m.issues.isNotEmpty)
                        Text(
                          '${l10n.miProblemsCount(m.issues.where((p) => p.blocking).length)}: '
                          '${m.issues.take(3).map((p) => '${masterProblemWhere(l10n, p)} ${masterProblemText(l10n, p)}').join(' / ')}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                        for (final f in m.files)
                          OutlinedButton.icon(
                            key: ValueKey('mi-row-${m.id}-${f.kind}'),
                            onPressed: () => downloadMasterFile(context, ref, f, save: saveFile),
                            icon: const Icon(Icons.download_outlined, size: 18),
                            label: Text(masterFileLabel(l10n, f)),
                          ),
                        if (m.status == MasterImportStatus.masterDone)
                          FilledButton.tonalIcon(
                            key: ValueKey('mi-row-${m.id}-stock'),
                            onPressed: () => _open(context, ref, resume: m.id),
                            icon: const Icon(Icons.inventory_outlined, size: 18),
                            label: Text(l10n.miOpenStock),
                          ),
                        if (m.status == MasterImportStatus.stockDone)
                          TextButton(
                            key: ValueKey('mi-row-${m.id}-result'),
                            onPressed: () => _open(context, ref, resume: m.id),
                            child: Text(l10n.miOpenResult),
                          ),
                      ]),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sets one product's stock in a warehouse to a figure by hand (0138). The
/// difference is booked as a correction; resolves to true when it changed.
Future<bool> showSetOnHandDialog(
  BuildContext context,
  WidgetRef ref, {
  required int warehouseId,
  required String janCode,
  required String name,
  required int current,
}) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _SetOnHandDialog(warehouseId: warehouseId, janCode: janCode, name: name, current: current),
  );
  return changed == true;
}

class _SetOnHandDialog extends ConsumerStatefulWidget {
  const _SetOnHandDialog({required this.warehouseId, required this.janCode, required this.name, required this.current});

  final int warehouseId;
  final String janCode;
  final String name;
  final int current;

  @override
  ConsumerState<_SetOnHandDialog> createState() => _SetOnHandDialogState();
}

class _SetOnHandDialogState extends ConsumerState<_SetOnHandDialog> {
  late final _qty = TextEditingController(text: '${widget.current}');
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final t = _qty.text.replaceAll(',', '').trim();
    if (!RegExp(r'^\d+$').hasMatch(t)) {
      setState(() => _error = l10n.miPbQtyInvalid(_qty.text));
      return;
    }
    final q = int.parse(t);
    if (q == widget.current) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(masterImportRepositoryProvider).setOnHand(widget.warehouseId, widget.janCode, q,
        note: _note.text.trim().isEmpty ? null : _note.text.trim());
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        ref.invalidate(productListProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.miSetOnHandDone(data.before, data.after))));
        Navigator.pop(context, true);
      case ApiFailure(:final message):
        setState(() {
          _busy = false;
          _error = humanizeApiErrorMessage(l10n, message);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.miSetOnHandTitle(widget.name)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.miSetOnHandHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const ValueKey('soh-qty'),
          controller: _qty,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.miOnHandNow, helperText: l10n.miSetOnHandWas(widget.current)),
        ),
        TextField(
          key: const ValueKey('soh-note'),
          controller: _note,
          decoration: InputDecoration(labelText: l10n.miSetOnHandNote),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ]),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
        FilledButton(key: const ValueKey('soh-save'), onPressed: _busy ? null : _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}

/// Whether the signed-in person may correct stock by hand (inventory.adjust).
final stockCanAdjustProvider = Provider<bool>(
    (ref) => ref.watch(authControllerProvider).user?.hasPermission('inventory.adjust') ?? false);

/// 在庫数 of one product in the active warehouse, with 在庫数を変更 for whoever
/// may adjust stock (0138).
class ProductOnHandRow extends ConsumerWidget {
  const ProductOnHandRow({super.key, required this.warehouseId, required this.janCode, required this.name, this.onChanged});

  final int warehouseId;
  final String janCode;
  final String name;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (janCode.trim().isEmpty) return const SizedBox.shrink();
    final canAdjust = ref.watch(stockCanAdjustProvider);
    final now = ref.watch(productOnHandProvider((warehouseId, janCode))).valueOrNull;
    return Row(children: [
      Expanded(
        child: Text(
          '${l10n.miOnHandNow}: ${now ?? '…'}',
          key: const ValueKey('soh-now'),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      if (canAdjust)
        TextButton.icon(
          key: const ValueKey('soh-open'),
          onPressed: now == null
              ? null
              : () async {
                  final changed = await showSetOnHandDialog(context, ref,
                      warehouseId: warehouseId, janCode: janCode, name: name, current: now);
                  if (changed) {
                    ref.invalidate(productOnHandProvider((warehouseId, janCode)));
                    onChanged?.call();
                  }
                },
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(l10n.miSetOnHand),
        ),
    ]);
  }
}
