import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/api/api_error_text.dart';
import '../../core/api/api_result.dart';
import '../../core/export/save_bytes.dart' show mimeTypeFor;
import '../../core/theme/app_spacing.dart';
import '../../core/ui/state_views.dart';
import '../../l10n/app_localizations.dart';
import '../delivery_note/delivery_note.dart' show askCameraOrFile, deliveryNotePickerProvider;
import '../master_import/data/master_import_repository.dart';
import '../payments/data/payments_repository.dart';
import '../stock_import/data/stock_import_repository.dart';
import '../stock_import/domain/stock_file.dart';
import '../stock_import/domain/stock_ledger.dart';
import '../stock_import/presentation/stock_inspection_screen.dart' show StockInspectionDetailScreen;

/// Days after which a receipt still without its invoice is shown in red.
const unplannedLateDays = 30;

String noInvoiceReasonLabel(AppLocalizations l10n, NoInvoiceReason r) => switch (r) {
      NoInvoiceReason.sample => l10n.urReasonSample,
      NoInvoiceReason.free => l10n.urReasonFree,
      NoInvoiceReason.supplierError => l10n.urReasonSupplierError,
      NoInvoiceReason.returned => l10n.urReasonReturned,
      NoInvoiceReason.other => l10n.urReasonOther,
    };

/// 請求書待ち (0183): the unplanned receipts no invoice covers yet, oldest
/// first, with how long they have waited — so none is forgotten.
///  * An invoice with its lines goes in through 発注 as usual: it is tied to
///    these by itself (one line may cover several receipts).
///  * A summary invoice with no lines: the receipts it covers are chosen here
///    and the invoice uploaded once for them (請求書を登録).
///  * One no invoice will come for (a sample, given free, the supplier's
///    mistake, returned): 請求書なしで完了, with the reason — and back to
///    waiting if one comes after all.
class UnplannedWaitingTab extends ConsumerStatefulWidget {
  const UnplannedWaitingTab({super.key});

  @override
  ConsumerState<UnplannedWaitingTab> createState() => _UnplannedWaitingTabState();
}

class _UnplannedWaitingTabState extends ConsumerState<UnplannedWaitingTab> {
  bool _settled = false;
  final Set<int> _chosen = {};
  bool _busy = false;

  void _refresh() {
    ref.invalidate(unplannedWaitingProvider(false));
    ref.invalidate(unplannedWaitingProvider(true));
  }

  Future<void> _settle(UnplannedWaiting w) async {
    final l10n = AppLocalizations.of(context);
    final got = await showDialog<(NoInvoiceReason, String)>(
      context: context,
      builder: (_) => _SettleDialog(importId: w.importId),
    );
    if (got == null || !mounted) return;
    final (reason, text) = got;
    final r = await ref
        .read(stockImportRepositoryProvider)
        .settleWithoutInvoice(w.importId, reason, note: text.isEmpty ? null : text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (r) {
      ApiSuccess() => l10n.urSettled(w.importId),
      ApiFailure(:final message) => humanizeApiErrorMessage(l10n, message),
    })));
    _chosen.remove(w.importId);
    _refresh();
  }

  Future<void> _reopen(UnplannedWaiting w) async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(stockImportRepositoryProvider).reopenInvoice(w.importId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (r) {
      ApiSuccess() => l10n.urReopened(w.importId),
      ApiFailure(:final message) => humanizeApiErrorMessage(l10n, message),
    })));
    _refresh();
  }

  /// A summary invoice for the receipts chosen: read by the AI (its header,
  /// amounts and 振込先 for 支払い and 税理士用ファイル), kept, and tied.
  Future<void> _invoice(List<UnplannedWaiting> chosen) async {
    final l10n = AppLocalizations.of(context);
    final suppliers = {for (final w in chosen) w.supplier ?? ''};
    final whs = {for (final w in chosen) w.warehouseId};
    if (whs.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errInvoiceMixedWarehouses)));
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.urInvoiceQ(chosen.length)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.urInvoiceBody(chosen.map((w) => '#${w.importId}').join('、'))),
          if (suppliers.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.urInvoiceSuppliers(suppliers.where((s) => s.isNotEmpty).join('、')),
                key: const ValueKey('uw-invoice-suppliers'),
                style: TextStyle(color: Theme.of(d).colorScheme.error)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.actionCancel)),
          FilledButton(
              key: const ValueKey('uw-invoice-go'), onPressed: () => Navigator.pop(d, true), child: Text(l10n.urInvoicePick)),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final camera = await askCameraOrFile(context);
    if (camera == null || !mounted) return;
    final f = await ref.read(deliveryNotePickerProvider)(camera: camera);
    if (f == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final read = await ref.read(masterImportRepositoryProvider).read(f.name, f.bytes, keepRows: true);
    if (!mounted) return;
    if (read case ApiFailure(:final message)) {
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
      return;
    }
    final data = (read as ApiSuccess).data;
    final repo = ref.read(stockImportRepositoryProvider);
    final r = await repo.createInvoiceFor(
      [for (final w in chosen) w.importId],
      fileName: f.name,
      fileType: mimeTypeFor(f.name),
      documentId: data.documentId,
      documentDate: DateTime.tryParse((data.docDate ?? '').replaceAll('/', '-')),
      read: [
        for (final l in data.lines)
          ReadRow(
            lineNo: l.lineNo,
            jan: l.janCode,
            name: l.supplierName,
            quantity: l.quantity,
            maker: l.maker,
            code: l.productCode,
            flags: l.flags,
            ledger: LedgerFields.fromJson(l.ledger),
          ),
      ],
    );
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(data: final id):
        // The original kept with it, as for 発注; then where it asks to be paid.
        await repo.keepFile(id, f.name, f.bytes, mimeTypeFor(f.name));
        unawaited(ref.read(paymentsRepositoryProvider).readPayee(id));
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(l10n.urInvoiced(id, chosen.length))));
        _chosen.clear();
        _refresh();
        ref.invalidate(masterImportsProvider);
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(unplannedWaitingProvider(_settled));
    final items = async.valueOrNull ?? const <UnplannedWaiting>[];
    final chosen = [for (final w in items) if (_chosen.contains(w.importId)) w];
    final now = DateTime.now();
    final day = DateFormat('y/MM/dd');
    return Column(children: [
      Expanded(
        child: ListView(
          key: const ValueKey('uw-list'),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(l10n.urWaitingIntro, style: muted),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, children: [
              ChoiceChip(
                key: const ValueKey('uw-show-waiting'),
                label: Text(l10n.urChipWaiting),
                selected: !_settled,
                onSelected: (_) => setState(() {
                  _settled = false;
                  _chosen.clear();
                }),
              ),
              ChoiceChip(
                key: const ValueKey('uw-show-settled'),
                label: Text(l10n.urChipSettled),
                selected: _settled,
                onSelected: (_) => setState(() {
                  _settled = true;
                  _chosen.clear();
                }),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            if (async.isLoading && items.isEmpty) const LoadingView(),
            if (!async.isLoading && items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(_settled ? l10n.urNoneSettled : l10n.urNoneWaiting,
                    key: const ValueKey('uw-none'), textAlign: TextAlign.center),
              ),
            for (final w in items)
              Card(
                key: ValueKey('uw-item-${w.importId}'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (!_settled)
                      Checkbox(
                        key: ValueKey('uw-pick-${w.importId}'),
                        value: _chosen.contains(w.importId),
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => v == true ? _chosen.add(w.importId) : _chosen.remove(w.importId)),
                      ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text([l10n.urItemTitle(w.importId), if (w.supplier case final s?) s].join(' · '),
                            style: theme.textTheme.titleSmall),
                        Text(
                          [
                            if (w.receivedAt case final at?) l10n.urReceivedOn(day.format(at)),
                            if (!_settled) l10n.urDaysWaiting(w.daysSince(now)),
                            if (w.warehouseName case final n?) n,
                          ].join(' · '),
                          key: ValueKey('uw-since-${w.importId}'),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: !_settled && w.daysSince(now) >= unplannedLateDays ? theme.colorScheme.error : null),
                        ),
                        for (final l in w.lines)
                          Text('${l.janCode} ${l.name ?? ''} ×${l.quantity}', style: muted, maxLines: 1),
                        if (w.invoicedLines > 0) Text(l10n.urPartlyInvoiced(w.invoicedLines), style: muted),
                        if (_settled && w.reason != null)
                          Text(
                            [
                              l10n.urSettledAs(noInvoiceReasonLabel(l10n, w.reason!)),
                              if (w.note case final n?) n,
                              if (w.settledAt case final at?) day.format(at),
                              if (w.settledBy case final b?) b,
                            ].join(' · '),
                            key: ValueKey('uw-reason-${w.importId}'),
                            style: theme.textTheme.bodySmall,
                          ),
                        Wrap(spacing: AppSpacing.xs, children: [
                          TextButton(
                            key: ValueKey('uw-open-${w.importId}'),
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => StockInspectionDetailScreen(importId: w.importId))),
                            child: Text(l10n.urDoneOpen),
                          ),
                          if (!_settled)
                            TextButton(
                              key: ValueKey('uw-settle-${w.importId}'),
                              onPressed: _busy ? null : () => _settle(w),
                              child: Text(l10n.urSettle),
                            )
                          else
                            TextButton(
                              key: ValueKey('uw-reopen-${w.importId}'),
                              onPressed: _busy ? null : () => _reopen(w),
                              child: Text(l10n.urReopen),
                            ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
      if (!_settled && chosen.isNotEmpty)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('uw-invoice'),
                onPressed: _busy ? null : () => _invoice(chosen),
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.receipt_long_outlined),
                label: Text(l10n.urInvoiceButton(chosen.length)),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Why no invoice will come: the reason, and a memo (required for その他).
/// Pops (reason, memo).
class _SettleDialog extends StatefulWidget {
  const _SettleDialog({required this.importId});

  final int importId;

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  var _reason = NoInvoiceReason.sample;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.urSettleQ(widget.importId)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.urSettleBody),
          for (final r in NoInvoiceReason.values)
            RadioListTile<NoInvoiceReason>(
              key: ValueKey('uw-reason-${r.wire}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: r,
              // ignore: deprecated_member_use
              groupValue: _reason,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _reason = v ?? _reason),
              title: Text(noInvoiceReasonLabel(l10n, r)),
            ),
          TextField(
            key: const ValueKey('uw-note'),
            controller: _note,
            decoration: InputDecoration(labelText: l10n.urSettleNote, border: const OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('uw-settle-go'),
          onPressed: _reason == NoInvoiceReason.other && _note.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (_reason, _note.text.trim())),
          child: Text(l10n.urSettleGo),
        ),
      ],
    );
  }
}
