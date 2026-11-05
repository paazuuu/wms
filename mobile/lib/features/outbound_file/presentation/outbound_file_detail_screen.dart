import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/application/product_providers.dart';
import '../../outbound/presentation/ship_destinations_screen.dart'
    show DestinationCardView, copyDestinationCard, pickDestinationCard;
import '../../admin/data/menu_visibility_repository.dart' show showPricesProvider;
import '../../packing/presentation/packing_screen.dart';
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

  Future<void> _setCard(OutboundFileSummary f) async {
    final l10n = AppLocalizations.of(context);
    final d = await pickDestinationCard(context);
    if (d?.id == null || !mounted) return;
    final r = await ref.read(outboundFileRepositoryProvider).setDestination(f.id, d!.id);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        ref.invalidate(outboundFileDetailProvider(widget.fileId));
        ref.invalidate(outboundFilesProvider);
        _snack(l10n.ofShipToSet);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  /// The warehouse ships a planned list: on a day (today unless chosen),
  /// what there is then going out.
  Future<void> _confirm(OutboundFileDetail d) async {
    final l10n = AppLocalizations.of(context);
    final f = d.file;
    var day = DateTime.now();
    final ship = [for (final l in d.lines) if (l.action == 'ship' && l.productId != null) l];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          key: const ValueKey('of-confirm-dialog'),
          icon: Icon(Icons.outbox_outlined, color: Theme.of(c).colorScheme.primary),
          title: Text(l10n.ofConfirmQ),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.ofConfirmBody(ship.length, ship.fold(0, (a, l) => a + l.quantity))),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('of-confirm-day'),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text('${l10n.ofConfirmDay}: ${DateFormat('y/MM/dd').format(day)}'),
              onPressed: () async {
                final picked = await showDatePicker(context: c, initialDate: day, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (picked != null) set(() => day = picked);
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
            FilledButton(key: const ValueKey('of-confirm-ok'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.ofConfirm)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(outboundFileRepositoryProvider).confirm(f.id, day);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        ref.invalidate(outboundFileDetailProvider(widget.fileId));
        ref.invalidate(outboundFilesProvider);
        ref.invalidate(productListProvider);
        _snack(l10n.ofConfirmDone(data));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _reschedule(OutboundFileSummary f) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDatePicker(
        context: context, initialDate: f.shippedOn, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked == null || !mounted) return;
    final r = await ref.read(outboundFileRepositoryProvider).reschedule(f.id, picked);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        ref.invalidate(outboundFileDetailProvider(widget.fileId));
        ref.invalidate(outboundFilesProvider);
        _snack(l10n.ofRescheduled(DateFormat('y/MM/dd').format(picked)));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _undo(OutboundFileSummary f) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(f.planned ? l10n.ofPlanCancelQ : (f.proxy ? l10n.prUndoQ : l10n.ofUndoQ)),
        content: Text(f.planned ? l10n.ofPlanCancelBody : (f.proxy ? l10n.prUndoBody : l10n.ofUndoBody(f.shippedTotal))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(
              key: const ValueKey('of-undo-ok'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(f.planned ? l10n.ofPlanCancel : (f.proxy ? l10n.prUndo : l10n.ofUndo))),
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
        _snack(f.planned ? l10n.ofPlanCancelled : (f.proxy ? l10n.prUndoDone : l10n.ofUndoDone(data)));
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
              if (f.planned)
                Text(l10n.ofPlannedFor(DateFormat('y/MM/dd').format(f.shippedOn)),
                    key: const ValueKey('of-detail-planned'),
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
              if (f.proxy)
                Text(l10n.prBadge,
                    key: const ValueKey('of-detail-proxy'),
                    style: TextStyle(color: scheme.tertiary, fontWeight: FontWeight.w600)),
              Text(f.fileName, key: const ValueKey('of-detail-name'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                [
                  if (!f.planned) '${l10n.ofShippedOn}: ${DateFormat('y/MM/dd').format(f.shippedOn)}',
                  if (!f.planned && f.plannedOn != null && f.plannedOn != f.shippedOn)
                    '${l10n.ofPlannedOn}: ${DateFormat('y/MM/dd').format(f.plannedOn!)}',
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
                Text(
                    f.proxy || f.planned
                        ? l10n.prCardLines(f.lineCount, f.quantityTotal)
                        : l10n.ofCardLines(f.lineCount, f.shippedTotal),
                    style: theme.textTheme.titleSmall),
                if (f.shortTotal > 0) Text(l10n.ofCardShort(f.shortTotal), style: TextStyle(color: scheme.error)),
                if (f.amountTotal != null && ref.watch(showPricesProvider)) Text(l10n.ofSummaryAmount(outboundMoney(f.amountTotal))),
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
                if (f.planned) ...[
                  FilledButton.icon(
                    key: const ValueKey('of-confirm'),
                    onPressed: _busy ? null : () => _confirm(d),
                    icon: const Icon(Icons.outbox_outlined),
                    label: Text(l10n.ofConfirm),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('of-reschedule'),
                    onPressed: _busy ? null : () => _reschedule(f),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: Text(l10n.ofReschedule),
                  ),
                ],
                if (!f.undone)
                  FilledButton.tonalIcon(
                    key: const ValueKey('of-packing'),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => PackingScreen(fileId: f.id))),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(l10n.ofPacking),
                  ),
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
        // 出荷先カード (0190): where it went, as the card was then.
        Card(
          key: const ValueKey('of-ship-to'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(l10n.ofShipTo, style: theme.textTheme.labelLarge)),
                if (f.shipTo != null)
                  IconButton(
                    key: const ValueKey('of-ship-to-copy'),
                    tooltip: l10n.sdcCopy,
                    icon: const Icon(Icons.copy_all_outlined),
                    onPressed: () => copyDestinationCard(context, f.shipTo!),
                  ),
                if (!f.undone)
                  TextButton.icon(
                    key: const ValueKey('of-ship-to-change'),
                    onPressed: () => _setCard(f),
                    icon: const Icon(Icons.contact_mail_outlined, size: 18),
                    label: Text(f.shipTo == null ? l10n.ofPickCard : l10n.ofShipToChange),
                  ),
              ]),
              if (f.shipTo != null) DestinationCardView(destination: f.shipTo!),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _table(l10n, d.lines.take(_limit).toList(), proxy: f.proxy || f.planned),
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
    // 表示設定 (0193): prices hidden from this user's tier.
    final prices = ref.watch(showPricesProvider);
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
                cell(10, Text(prices ? outboundMoney(l.unitPrice) : '—', style: small), end: true),
                cell(11, Text(prices ? outboundMoney(l.unitPriceTax) : '—', style: small), end: true),
                cell(12, Text(prices ? outboundMoney(l.amount) : '—', style: small), end: true),
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
