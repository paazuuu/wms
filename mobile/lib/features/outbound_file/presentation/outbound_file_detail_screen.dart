import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/application/product_providers.dart';
import '../data/outbound_file_repository.dart';
import 'outbound_file_screen.dart'
    show outboundActionLabel, outboundFileSaverProvider, outboundKg, outboundMoney, outboundTabOpenerProvider;

/// One shipped list: when, where, by whom; its file — opened in a new tab as
/// it was uploaded, or downloaded — every row with what went out and what
/// was short; and the shipment taken back.
class OutboundFileDetailScreen extends ConsumerStatefulWidget {
  const OutboundFileDetailScreen({super.key, required this.fileId});

  final int fileId;

  @override
  ConsumerState<OutboundFileDetailScreen> createState() => _OutboundFileDetailScreenState();
}

class _OutboundFileDetailScreenState extends ConsumerState<OutboundFileDetailScreen> {
  final _across = ScrollController();
  bool _busy = false;
  int _limit = 200;

  @override
  void dispose() {
    _across.dispose();
    super.dispose();
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  /// Opened from the click (a tab first, then the bytes), so the browser
  /// lets it open.
  Future<void> _open(OutboundFileSummary f) async {
    final l10n = AppLocalizations.of(context);
    final tab = ref.read(outboundTabOpenerProvider)();
    final r = await ref.read(outboundFileRepositoryProvider).fileBytes(f.storagePath!);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        if (tab != null) {
          tab.showBytes(data, f.mime);
        } else {
          await ref.read(outboundFileSaverProvider)(f.fileName, data);
        }
      case ApiFailure(:final message):
        tab?.close();
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _download(OutboundFileSummary f) async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(outboundFileRepositoryProvider).fileBytes(f.storagePath!);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        await ref.read(outboundFileSaverProvider)(f.fileName, data);
        _snack(l10n.ofFileSaved(f.fileName));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _undo(OutboundFileSummary f) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(f.proxy ? l10n.prUndoQ : l10n.ofUndoQ),
        content: Text(f.proxy ? l10n.prUndoBody : l10n.ofUndoBody(f.shippedTotal)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(
              key: const ValueKey('of-undo-ok'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(f.proxy ? l10n.prUndo : l10n.ofUndo)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(outboundFileRepositoryProvider).undo(f.id);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        ref.invalidate(outboundFileDetailProvider(widget.fileId));
        ref.invalidate(outboundFilesProvider);
        ref.invalidate(productListProvider);
        _snack(f.proxy ? l10n.prUndoDone : l10n.ofUndoDone(data));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(outboundFileDetailProvider(widget.fileId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ofDetailTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
            message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(outboundFileDetailProvider(widget.fileId))),
        data: (d) => _body(l10n, d),
      ),
    );
  }

  Widget _body(AppLocalizations l10n, OutboundFileDetail d) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final f = d.file;
    final weight = d.lines.fold<double>(0, (a, l) => a + (l.weightG ?? 0));
    return ListView(
      key: const ValueKey('of-detail'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (f.proxy)
                Text(l10n.prBadge,
                    key: const ValueKey('of-detail-proxy'),
                    style: TextStyle(color: scheme.tertiary, fontWeight: FontWeight.w600)),
              Text(f.fileName, key: const ValueKey('of-detail-name'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                [
                  '${l10n.ofShippedOn}: ${DateFormat('y/MM/dd').format(f.shippedOn)}',
                  if (f.warehouseName != null) f.warehouseName!,
                  if (f.sheetName != null) '${l10n.ofSheet}: ${f.sheetName}',
                  if (f.destination != null) f.destination!,
                  if (f.principal != null) l10n.prPrincipalLabel(f.principal!),
                ].join(' · '),
                style: muted,
              ),
              if (f.note != null) Text(f.note!, style: theme.textTheme.bodyMedium),
              if (f.createdByName != null && f.createdAt != null)
                Text(l10n.ofBy(f.createdByName!, DateFormat('y/MM/dd HH:mm').format(f.createdAt!)), style: muted),
              if (f.undone)
                Text(
                  [l10n.ofUndone, if (d.undoneByName != null) d.undoneByName!, DateFormat('y/MM/dd HH:mm').format(f.undoneAt!)].join(' · '),
                  key: const ValueKey('of-detail-undone'),
                  style: TextStyle(color: scheme.error),
                ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.xs, children: [
                Text(f.proxy ? l10n.prCardLines(f.lineCount, f.quantityTotal) : l10n.ofCardLines(f.lineCount, f.shippedTotal),
                    style: theme.textTheme.titleSmall),
                if (f.shortTotal > 0) Text(l10n.ofCardShort(f.shortTotal), style: TextStyle(color: scheme.error)),
                if (f.amountTotal != null) Text(l10n.ofSummaryAmount(outboundMoney(f.amountTotal))),
                if (weight > 0) Text(l10n.ofSummaryWeight(outboundKg(weight))),
              ]),
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                if (f.storagePath != null) ...[
                  FilledButton.tonalIcon(
                    key: const ValueKey('of-open-file'),
                    onPressed: () => _open(f),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.ofOpenFile),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('of-download'),
                    onPressed: () => _download(f),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(l10n.ofDownload),
                  ),
                ] else
                  Text(l10n.ofNoFile, style: muted),
                if (!f.undone)
                  TextButton.icon(
                    key: const ValueKey('of-undo'),
                    onPressed: _busy ? null : () => _undo(f),
                    icon: const Icon(Icons.undo),
                    label: Text(f.proxy ? l10n.prUndo : l10n.ofUndo),
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                  ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _table(l10n, d.lines.take(_limit).toList(), proxy: f.proxy),
        if (d.lines.length > _limit)
          TextButton(onPressed: () => setState(() => _limit += 300), child: Text(l10n.ppMore(d.lines.length - _limit))),
      ],
    );
  }

  Widget _table(AppLocalizations l10n, List<OutboundFileLine> lines, {bool proxy = false}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final head = theme.textTheme.labelMedium;
    final small = theme.textTheme.bodySmall;
    const widths = [52.0, 96.0, 250.0, 128.0, 128.0, 96.0, 104.0, 72.0, 72.0, 64.0, 80.0, 80.0, 100.0, 84.0, 96.0, 110.0];
    // 代理出荷: nothing taken out of stock — no 出庫数, 不足 or stock columns.
    final hidden = proxy ? const {8, 9, 15} : const <int>{};
    Widget cell(int i, Widget child, {bool end = false}) => hidden.contains(i)
        ? const SizedBox.shrink()
        : Container(
            width: widths[i],
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            alignment: end ? Alignment.centerRight : Alignment.centerLeft,
            child: child,
          );
    final headers = [
      l10n.ofColRow, l10n.ofColAction, l10n.ofColProduct, l10n.ofRoleJan, l10n.ofRoleCode, l10n.ofRoleMaker,
      l10n.ofRoleSupplier, l10n.ofRoleQuantity, l10n.ofColShip, l10n.ofColShort, l10n.ofColPriceEx, l10n.ofColPriceTax,
      l10n.ofRoleAmount, l10n.ofColWeight, l10n.ofRoleOrderNumber, l10n.ofColStock,
    ];
    const ends = {7, 8, 9, 10, 11, 12, 13, 15};
    return Scrollbar(
      controller: _across,
      thumbVisibility: true,
      child: SingleChildScrollView(
        key: const ValueKey('of-detail-table'),
        controller: _across,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            color: scheme.surfaceContainerHighest,
            child: Row(children: [for (final (i, h) in headers.indexed) cell(i, Text(h, style: head), end: ends.contains(i))]),
          ),
          for (final l in lines)
            Container(
              key: ValueKey('of-line-${l.rowNo}'),
              decoration: BoxDecoration(
                color: l.action == 'skip' ? scheme.surfaceContainerLow : null,
                border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(children: [
                cell(0, Text('${l.rowNo}', style: small)),
                cell(1, Text(outboundActionLabel(l10n, l.action), style: small)),
                cell(2, Text(l.productName ?? '', maxLines: 2, overflow: TextOverflow.ellipsis)),
                cell(3, Text(l.jan ?? '', style: small)),
                cell(4, Text(l.code ?? '', style: small, maxLines: 2, overflow: TextOverflow.ellipsis)),
                cell(5, Text(l.maker ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
                cell(6, Text(l.supplier ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
                cell(7, Text('${l.quantity}', style: theme.textTheme.titleSmall), end: true),
                cell(8, Text(l.action == 'ship' ? '${l.shippedQuantity}' : '—', key: ValueKey('of-line-ship-${l.rowNo}')), end: true),
                cell(
                  9,
                  Text(l.shortQuantity > 0 ? '${l.shortQuantity}' : '',
                      style: small?.copyWith(color: scheme.error, fontWeight: FontWeight.w700)),
                  end: true,
                ),
                cell(10, Text(outboundMoney(l.unitPrice), style: small), end: true),
                cell(11, Text(outboundMoney(l.unitPriceTax), style: small), end: true),
                cell(12, Text(outboundMoney(l.amount), style: small), end: true),
                cell(13, Text(l.weightG == null ? '' : '${outboundKg(l.weightG!)} kg', style: small), end: true),
                cell(14, Text(l.orderNumber ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
                cell(15, Text(l.onHandBefore == null ? '' : '${l.onHandBefore} → ${l.onHandAfter}', style: small), end: true),
              ]),
            ),
        ]),
      ),
    );
  }
}
