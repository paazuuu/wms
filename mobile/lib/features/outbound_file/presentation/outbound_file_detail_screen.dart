import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/application/product_providers.dart';
import '../../outbound/presentation/ship_destinations_screen.dart'
    show DestinationCardView, copyDestinationCard, pickDestinationCard;
import '../../admin/data/menu_visibility_repository.dart' show showPricesProvider;
import '../../packing/domain/packing.dart' show packEstimateOf;
import '../../packing/presentation/packing_lists_screen.dart' show packingKg;
import '../../packing/presentation/packing_screen.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart' show Warehouse;
import '../data/outbound_file_repository.dart';
import '../domain/outbound_currency.dart' show PriceCurrency;
import 'outbound_file_screen.dart'
    show outboundActionLabel, outboundFileSaverProvider, outboundKg, outboundMoney, outboundTabOpenerProvider;

/// The warehouse a list not yet shipped goes from, chosen again (0199):
/// true when it changed.
Future<bool> changeOutboundWarehouse(BuildContext context, WidgetRef ref, OutboundFileSummary f) async {
  final l10n = AppLocalizations.of(context);
  var warehouses = ref.read(warehouseOverviewProvider).valueOrNull?.warehouses;
  if (warehouses == null) {
    try {
      warehouses = (await ref.read(warehouseOverviewProvider.future)).warehouses;
    } catch (_) {
      warehouses = const <Warehouse>[];
    }
  }
  if (!context.mounted) return false;
  final picked = await showDialog<Warehouse>(
    context: context,
    builder: (c) => AlertDialog(
      key: const ValueKey('of-warehouse-dialog'),
      icon: const Icon(Icons.warehouse_outlined),
      title: Text(l10n.ofWarehouseChangeQ),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.ofWarehouseChangeBody, style: Theme.of(c).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final w in warehouses!)
                if (w.status == 'active' || w.id == f.warehouseId)
                ListTile(
                  key: ValueKey('of-warehouse-pick-${w.id}'),
                  leading: Icon(w.id == f.warehouseId ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: w.id == f.warehouseId ? Theme.of(c).colorScheme.primary : null),
                  title: Text(w.name),
                  subtitle: Text(w.code),
                  onTap: () => Navigator.pop(c, w),
                ),
            ]),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(l10n.actionCancel))],
    ),
  );
  if (picked == null || picked.id == f.warehouseId || !context.mounted) return false;
  final r = await ref.read(outboundFileRepositoryProvider).setWarehouse(f.id, picked.id);
  if (!context.mounted) return false;
  switch (r) {
    case ApiSuccess():
      ref.invalidate(outboundFileDetailProvider(f.id));
      ref.invalidate(outboundFilesProvider);
      ref.invalidate(outboundUndecidedProvider);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.ofWarehouseChanged(picked.name))));
      return true;
    case ApiFailure(:final message):
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
      return false;
  }
}

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

  /// After any change: this list, the calendar, the 未定 lists (dashboard,
  /// 出荷手配) and the stock — so nothing shows what was before.
  void _refreshAll() {
    ref.invalidate(outboundFileDetailProvider(widget.fileId));
    ref.invalidate(outboundFilesProvider);
    ref.invalidate(outboundUndecidedProvider);
    ref.invalidate(productListProvider);
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
        _refreshAll();
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var day = today;
    // Pressed once the goods have left: ticked to say so.
    var seen = false;
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
            if (f.undecided) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.ofUndecidedConfirmNote,
                  key: const ValueKey('of-confirm-undecided'),
                  style: TextStyle(color: Theme.of(c).colorScheme.warning, fontWeight: FontWeight.w600)),
            ],
            if (d.short.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.ofConfirmShortNote(d.short.fold(0, (a, x) => a + x.short)),
                  key: const ValueKey('of-confirm-short'),
                  style: TextStyle(color: Theme.of(c).colorScheme.error, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: AppSpacing.sm),
            // The day it left: today or before, never ahead.
            OutlinedButton.icon(
              key: const ValueKey('of-confirm-day'),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text('${l10n.ofConfirmDay}: ${DateFormat('y/MM/dd').format(day)}'),
              onPressed: () async {
                final picked = await showDatePicker(context: c, initialDate: day, firstDate: DateTime(2000), lastDate: today);
                if (picked != null) set(() => day = picked);
              },
            ),
            if (!f.undecided && day.isBefore(f.shippedOn)) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.ofConfirmEarly(DateFormat('y/MM/dd').format(f.shippedOn)),
                  key: const ValueKey('of-confirm-early'),
                  style: TextStyle(color: Theme.of(c).colorScheme.warning)),
            ],
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              key: const ValueKey('of-confirm-check'),
              value: seen,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.ofConfirmCheck, style: const TextStyle(fontWeight: FontWeight.w600)),
              onChanged: (v) => set(() => seen = v ?? false),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
            FilledButton(
                key: const ValueKey('of-confirm-ok'),
                onPressed: seen ? () => Navigator.pop(c, true) : null,
                child: Text(l10n.ofConfirm)),
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
        _refreshAll();
        _snack(l10n.ofConfirmDone(data));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _reschedule(OutboundFileSummary f) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDatePicker(
        context: context,
        initialDate: f.undecided ? DateTime.now() : f.shippedOn,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (picked == null || !mounted) return;
    final r = await ref.read(outboundFileRepositoryProvider).reschedule(f.id, picked);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        _refreshAll();
        _snack(l10n.ofRescheduled(DateFormat('y/MM/dd').format(picked)));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  /// A shipped list that did not leave after all: back to planned, 未定 (0201).
  Future<void> _backToPlan(OutboundFileSummary f) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.ofBackToPlanQ),
        content: Text(l10n.ofBackToPlanBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(
              key: const ValueKey('of-back-to-plan-ok'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.ofBackToPlan)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(outboundFileRepositoryProvider).backToPlan(f.id);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        _refreshAll();
        _snack(l10n.ofBackToPlanDone(data));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  /// A planned list back to 出庫日 未定 (0197).
  Future<void> _toUndecided(OutboundFileSummary f) async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(outboundFileRepositoryProvider).markUndecided(f.id);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        _refreshAll();
        _snack(l10n.ofMadeUndecided);
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
        _refreshAll();
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
    // 総重量の見積もり (0199), once anything beyond the products is set.
    final est = packEstimateOf(packDemandsOf(d),
        cartonCount: f.packCartonCount, cartonKg: f.packCartonKg, materialKg: f.packMaterialKg);
    final estimate = est.undecided ? null : est;
    return ListView(
      key: const ValueKey('of-detail'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // No day yet: said first, with the way to set one.
        if (f.undecided && !f.undone)
          Card(
            key: const ValueKey('of-detail-undecided'),
            color: scheme.warningContainer,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(children: [
                Icon(Icons.event_busy_outlined, color: scheme.onWarningContainer),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.ofUndecidedBannerTitle,
                        style: theme.textTheme.titleSmall?.copyWith(color: scheme.onWarningContainer)),
                    Text(l10n.ofUndecidedBannerBody,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onWarningContainer)),
                  ]),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  key: const ValueKey('of-detail-set-day'),
                  onPressed: _busy ? null : () => _reschedule(f),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: Text(l10n.ofSetDay),
                ),
              ]),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Where it stands: planned (nothing has left yet) or shipped
              // (who recorded it, when) — a planned day is not a shipment.
              if (f.planned)
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: l10n.ofPlannedFor(f.undecided ? l10n.ofUndecided : DateFormat('y/MM/dd').format(f.shippedOn)),
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                    TextSpan(text: '  ${l10n.ofStatusPlanned}', style: muted),
                  ]),
                  key: const ValueKey('of-detail-planned'),
                )
              else if (!f.proxy && !f.undone && f.autoShipped && d.shippedAt != null)
                Text(
                    l10n.ofStatusAutoShipped(
                        DateFormat('y/MM/dd').format(f.shippedOn), DateFormat('y/MM/dd HH:mm').format(d.shippedAt!)),
                    key: const ValueKey('of-detail-shipped'),
                    style: TextStyle(color: scheme.success, fontWeight: FontWeight.w700))
              else if (!f.proxy && !f.undone && d.shippedByName != null && d.shippedAt != null)
                Text(
                    l10n.ofStatusShipped(DateFormat('y/MM/dd').format(f.shippedOn), d.shippedByName!,
                        DateFormat('y/MM/dd HH:mm').format(d.shippedAt!)),
                    key: const ValueKey('of-detail-shipped'),
                    style: TextStyle(color: scheme.success, fontWeight: FontWeight.w700)),
              if (f.proxy)
                Text(l10n.prBadge,
                    key: const ValueKey('of-detail-proxy'),
                    style: TextStyle(color: scheme.tertiary, fontWeight: FontWeight.w600)),
              Text(f.fileName, key: const ValueKey('of-detail-name'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                [
                  if (!f.planned) '${l10n.ofShippedOn}: ${f.undecided ? l10n.ofUndecided : DateFormat('y/MM/dd').format(f.shippedOn)}',
                  if (!f.planned && f.plannedOn != null && f.plannedOn != f.shippedOn)
                    '${l10n.ofPlannedOn}: ${DateFormat('y/MM/dd').format(f.plannedOn!)}',
                  if (f.sheetName != null) '${l10n.ofSheet}: ${f.sheetName}',
                  if (f.destination != null) f.destination!,
                  if (f.principal != null) l10n.prPrincipalLabel(f.principal!),
                ].join(' · '),
                style: muted,
              ),
              // 出庫元の倉庫: changed here while nothing has left stock (0199).
              Row(key: const ValueKey('of-detail-warehouse'), children: [
                Icon(Icons.warehouse_outlined, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Flexible(child: Text(l10n.ofWarehouseFrom(f.warehouseName ?? '#${f.warehouseId}'), style: theme.textTheme.bodyMedium)),
                const SizedBox(width: AppSpacing.xs),
                if (f.warehouseMovable)
                  TextButton.icon(
                    key: const ValueKey('of-warehouse-change'),
                    onPressed: _busy ? null : () => changeOutboundWarehouse(context, ref, f),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: Text(l10n.ofWarehouseChange),
                  )
                else if (!f.undone)
                  Tooltip(
                    message: l10n.ofWarehouseFixed,
                    child: Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
                  ),
              ]),
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
                if (f.amountTotal != null && ref.watch(showPricesProvider)) Text(l10n.ofSummaryAmount(_amountByCurrency(d))),
                if (f.fxCnyJpy != null && ref.watch(showPricesProvider)) Text(l10n.ofFxShown(outboundMoney(f.fxCnyJpy))),
                if (weight > 0) Text(l10n.ofSummaryWeight(outboundKg(weight))),
                if (estimate != null)
                  Text(l10n.ofEstTotal(packingKg(estimate.totalKg)),
                      key: const ValueKey('of-detail-estimate'), style: const TextStyle(fontWeight: FontWeight.w700)),
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
                if (f.planned)
                  FilledButton.icon(
                    key: const ValueKey('of-confirm'),
                    onPressed: _busy ? null : () => _confirm(d),
                    icon: const Icon(Icons.outbox_outlined),
                    label: Text(l10n.ofConfirm),
                  ),
                // A 在庫外出荷's day can be 未定 too (0198): set or changed here.
                if (f.planned || (f.proxy && !f.undone)) ...[
                  OutlinedButton.icon(
                    key: const ValueKey('of-reschedule'),
                    onPressed: _busy ? null : () => _reschedule(f),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: Text(f.undecided ? l10n.ofSetDay : l10n.ofReschedule),
                  ),
                  if (!f.undecided)
                    TextButton(
                      key: const ValueKey('of-to-undecided'),
                      onPressed: _busy ? null : () => _toUndecided(f),
                      child: Text(l10n.ofBackToUndecided),
                    ),
                ],
                if (!f.undone)
                  FilledButton.tonalIcon(
                    key: const ValueKey('of-packing'),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => PackingScreen(fileId: f.id))),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(l10n.ofPackingWeight),
                  ),
                if (!f.undone && !f.planned && !f.proxy)
                  OutlinedButton.icon(
                    key: const ValueKey('of-back-to-plan'),
                    onPressed: _busy ? null : () => _backToPlan(f),
                    icon: const Icon(Icons.settings_backup_restore),
                    label: Text(l10n.ofBackToPlan),
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
        // キープ and the night run (0201): a planned list of stock says whether
        // all is there; what is short holds it back.
        if (f.planned && !f.proxy) ...[
          const SizedBox(height: AppSpacing.md),
          _keepCard(l10n, d),
        ],
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

  Widget _keepCard(AppLocalizations l10n, OutboundFileDetail d) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = d.file;
    final short = d.short;
    final day = DateFormat('y/MM/dd').format(f.shippedOn);
    if (short.isEmpty) {
      return Card(
        key: const ValueKey('of-detail-keep'),
        color: scheme.successContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            Icon(Icons.inventory_outlined, color: scheme.onSuccessContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(f.dateUndecided ? l10n.ofAutoUndecided : l10n.ofAutoReady(day),
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSuccessContainer)),
            ),
          ]),
        ),
      );
    }
    final total = short.fold(0, (a, x) => a + x.short);
    final held = f.overdue(DateTime.now());
    return Card(
      key: const ValueKey('of-detail-short'),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(held ? l10n.ofShortHeld(day) : l10n.ofShortTitle(short.length, total),
                  key: const ValueKey('of-detail-short-title'),
                  style: theme.textTheme.titleSmall?.copyWith(color: scheme.onErrorContainer)),
            ),
          ]),
          if (held) Text(l10n.ofShortTitle(short.length, total), style: TextStyle(color: scheme.onErrorContainer)),
          const SizedBox(height: AppSpacing.xs),
          for (final x in short.take(30))
            Text(l10n.ofShortRow(x.name ?? x.jan ?? '?', x.needed, x.onHand, x.keptAhead, x.short),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer)),
          if (short.length > 30) Text(l10n.ppMore(short.length - 30), style: TextStyle(color: scheme.onErrorContainer)),
        ]),
      ),
    );
  }

  /// A price with its currency's mark when not 円 (0197).
  String _money(OutboundFileLine l, double? v) {
    if (v == null) return '';
    final c = PriceCurrency.fromWire(l.currency);
    return c == PriceCurrency.jpy ? outboundMoney(v) : '${outboundMoney(v)} ${c.mark}';
  }

  TextStyle? _moneyStyle(OutboundFileLine l, TextStyle? small, ColorScheme scheme) =>
      l.currency == 'JPY' ? small : small?.copyWith(color: scheme.tertiary, fontWeight: FontWeight.w700);

  /// The list's amount by currency: 1,000 · 50 元.
  String _amountByCurrency(OutboundFileDetail d) {
    final by = <PriceCurrency, double>{};
    for (final l in d.lines) {
      if (l.amount == null) continue;
      final c = PriceCurrency.fromWire(l.currency);
      by[c] = (by[c] ?? 0) + l.amount!;
    }
    if (by.isEmpty) return outboundMoney(d.file.amountTotal);
    if (by.length == 1 && by.keys.single == PriceCurrency.jpy) return outboundMoney(by.values.single);
    return [for (final e in by.entries) '${outboundMoney(e.value)} ${e.key.mark}'].join(' · ');
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
    // 仕入先 (6) is ours to know, not the shipping side's: kept, not shown.
    final hidden = proxy ? const {6, 8, 9, 15} : const {6};
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
                cell(10, Text(prices ? _money(l, l.unitPrice) : '—', style: _moneyStyle(l, small, scheme)), end: true),
                cell(11, Text(prices ? _money(l, l.unitPriceTax) : '—', style: _moneyStyle(l, small, scheme)), end: true),
                cell(12, Text(prices ? _money(l, l.amount) : '—', style: _moneyStyle(l, small, scheme)), end: true),
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
