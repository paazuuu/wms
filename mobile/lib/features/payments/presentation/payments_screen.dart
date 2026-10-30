import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/copy_text.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../master_import/data/master_import_repository.dart' show masterImportsProvider;
import '../../stock_import/presentation/import_view_screen.dart' show importDetailProvider, openReadingTable;
import '../../stock_import/presentation/stock_import_calendar_screen.dart' show stockImportMonthProvider;
import '../../tax_files/data/tax_files_repository.dart';
import '../data/payments_repository.dart';
import '../domain/payment.dart';

/// A picked file: its name and bytes, or null when nothing was chosen.
typedef PickProof = Future<({String name, Uint8List bytes})?> Function();

Future<({String name, Uint8List bytes})?> _pickProof() async {
  final r = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'heic', 'pdf'],
  );
  final f = r?.files.firstOrNull;
  if (f?.bytes == null) return null;
  return (name: f!.name, bytes: f.bytes!);
}

/// Overridden in tests so nothing reaches for the platform.
final paymentProofPickerProvider = Provider<PickProof>((_) => _pickProof);

/// Saves a file (the invoice, a proof); tests stand in for the download.
final paymentFileSaverProvider =
    Provider<Future<void> Function(String name, Uint8List bytes)>((ref) => (name, bytes) async => saveBytes(name, bytes));

final _yen = NumberFormat.decimalPattern();
final _day = DateFormat('y/MM/dd');
final _at = DateFormat('y/MM/dd HH:mm');

/// 会計 → 支払い (0171): every invoice taken into stock as a payment to make
/// — to whom (the 振込先 the invoice prints, else the supplier's), how much,
/// the invoice it came from, 支払い済 (the import's own, so it is the same
/// tick everywhere) and the proof of the transfer kept beside it.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key, this.today, this.embedded = false});

  /// For tests: the month the month view starts on.
  final DateTime? today;

  /// Shown inside 発注 (its own tab): no bar of its own.
  final bool embedded;

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

/// Orders whose 振込先 the AI was already asked for, this session.
final payeeAskedProvider = Provider<Set<int>>((_) => <int>{});

/// Orders shown under 進行中 this session: kept there once through (paid,
/// its proof added) so the card does not close under one's hand — the
/// inspection may still be going.
final keptOrdersProvider = Provider<Set<int>>((_) => <int>{});

/// The order just taken in (発注 → ファイルを取り込む): shown first, open.
final focusedOrderProvider = StateProvider<int?>((_) => null);

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  late DateTime _month = DateTime((widget.today ?? DateTime.now()).year, (widget.today ?? DateTime.now()).month);
  bool _open = true;

  PaymentsRange get _range => _open ? const OpenPayments() : MonthPayments(_month.year, _month.month);

  /// An unpaid order with no 振込先 has its invoice read for one by the AI,
  /// once — what the reading of the stock did not find.
  void _askPayees(List<Payment> all, {required bool can}) {
    if (!can) return;
    final asked = ref.read(payeeAskedProvider);
    final ask = [
      for (final p in all)
        if (!p.paid && p.payee == null && !asked.contains(p.importId)) p.importId,
    ];
    if (ask.isEmpty) return;
    asked.addAll(ask);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var found = false;
      for (final id in ask) {
        final r = await ref.read(paymentsRepositoryProvider).readPayee(id);
        if (r case ApiSuccess(:final data) when data != null) found = true;
      }
      if (found && mounted) ref.invalidate(paymentsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(paymentsProvider(_range));
    final can = ref.watch(canRecordPaymentsProvider);
    final focus = ref.watch(focusedOrderProvider);
    final body = ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(l10n.payIntro, style: muted),
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ChoiceChip(
            key: const ValueKey('pay-open'),
            label: Text(l10n.payOpen),
            selected: _open,
            onSelected: (_) => setState(() => _open = true),
          ),
          ChoiceChip(
            key: const ValueKey('pay-by-month'),
            label: Text(l10n.payByMonth),
            selected: !_open,
            onSelected: (_) => setState(() => _open = false),
          ),
          if (!_open) ...[
            IconButton(
              key: const ValueKey('pay-prev'),
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            ),
            Text(l10n.txMonth(_month.year, _month.month), key: const ValueKey('pay-month')),
            IconButton(
              key: const ValueKey('pay-next'),
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            ),
          ],
        ]),
        const SizedBox(height: AppSpacing.sm),
        ...async.when(
          loading: () => const [LoadingView()],
          error: (e, _) => [
            ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(paymentsProvider)),
          ],
          data: (all) {
            _askPayees(all, can: can);
            final kept = ref.read(keptOrdersProvider);
            final shown = _open ? [for (final p in all) if (!p.complete || kept.contains(p.importId)) p] : all;
            if (_open) kept.addAll(shown.map((p) => p.importId));
            // The order just taken in first.
            shown.sort((a, b) => (b.importId == focus ? 1 : 0) - (a.importId == focus ? 1 : 0));
            if (shown.isEmpty) return [Text(_open ? l10n.payNoneOpen : l10n.payNone, key: const ValueKey('pay-none'))];
            final unpaid = shown.where((p) => !p.paid);
            final due = unpaid.fold<double>(0, (s, p) => s + p.amount);
            return [
              Text(
                l10n.paySummary(shown.length, unpaid.length, _yen.format(due.round())),
                key: const ValueKey('pay-summary'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final p in shown)
                PaymentCard(
                  key: ValueKey('pay-card-state-${p.importId}'),
                  payment: p,
                  initiallyOpen: p.importId == focus || shown.length == 1,
                ),
            ];
          },
        ),
      ],
    );
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: Text(l10n.featPayments)), body: body);
  }
}

/// Everything about a payment changed: what shows it is read again.
void refreshPayments(WidgetRef ref, int importId) {
  ref.invalidate(paymentsProvider);
  ref.invalidate(taxMonthsProvider);
  ref.invalidate(importDetailProvider(importId));
  ref.invalidate(masterImportsProvider);
  ref.invalidate(stockImportMonthProvider);
}

class PaymentCard extends ConsumerStatefulWidget {
  const PaymentCard({super.key, required this.payment, this.initiallyOpen = false});

  final Payment payment;

  /// Shown with every step (else the summary line and the bar of steps).
  final bool initiallyOpen;

  @override
  ConsumerState<PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends ConsumerState<PaymentCard> {
  bool _busy = false;
  late bool _openCard = widget.initiallyOpen;

  Payment get p => widget.payment;

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _run(Future<ApiResult<bool>> Function() step) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await step();
    if (!mounted) return false;
    setState(() => _busy = false);
    if (r case ApiFailure(:final message)) {
      _snack(humanizeApiErrorMessage(l10n, message));
      return false;
    }
    return true;
  }

  Future<void> _setPaid(bool paid) async {
    final l10n = AppLocalizations.of(context);
    // Another order like this one already paid: asked once more, so the same
    // order is not paid twice — it may be a new order of the same goods.
    final paidTwin = p.sameAs.where((o) => o.paid).firstOrNull;
    if (paid && paidTwin != null) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l10n.payTwinTitle),
          content: Text(l10n.payTwinBody(paidTwin.importId)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
            FilledButton(key: const ValueKey('pay-twin-ok'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.payTwinGo)),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    if (await _run(() => ref.read(paymentsRepositoryProvider).setPaid(p.importId, paid))) {
      _snack(paid ? l10n.payMarkedPaid : l10n.payMarkedUnpaid);
      refreshPayments(ref, p.importId);
    }
  }

  /// A proof added marks the payment paid: a transfer that has a proof was
  /// made.
  Future<void> _addProof() async {
    final l10n = AppLocalizations.of(context);
    final f = await ref.read(paymentProofPickerProvider)();
    if (f == null || !mounted) return;
    final repo = ref.read(paymentsRepositoryProvider);
    if (!await _run(() => repo.addProof(p.importId, f.name, f.bytes))) return;
    var text = l10n.payProofAdded(f.name);
    if (!p.paid && await _run(() => repo.setPaid(p.importId, true))) text = l10n.payProofAddedPaid(f.name);
    if (!mounted) return;
    _snack(text);
    refreshPayments(ref, p.importId);
  }

  Future<void> _removeProof(PaymentProof proof) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.payProofRemoveTitle),
        content: Text(l10n.payProofRemoveBody(proof.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(
            key: const ValueKey('pay-proof-remove-ok'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.payProofRemove),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (await _run(() => ref.read(paymentsRepositoryProvider).removeProof(proof.id))) refreshPayments(ref, p.importId);
  }

  Future<void> _openProof(PaymentProof proof) async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(paymentsRepositoryProvider).proofBytes(proof);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data) when proof.isImage:
        await showDialog<void>(
          context: context,
          builder: (c) => Dialog(
            key: const ValueKey('pay-proof-view'),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                title: Text(proof.name),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: l10n.payDownload,
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () => ref.read(paymentFileSaverProvider)(proof.name, data),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c)),
                ]),
              ),
              Flexible(child: InteractiveViewer(child: Image.memory(data, fit: BoxFit.contain))),
            ]),
          ),
        );
      case ApiSuccess(:final data):
        await ref.read(paymentFileSaverProvider)(proof.name, data);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _downloadProof(PaymentProof proof) async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(paymentsRepositoryProvider).proofBytes(proof);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        await ref.read(paymentFileSaverProvider)(proof.name, data);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _invoice() async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(taxFilesRepositoryProvider).original(p.purchase);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        await ref.read(paymentFileSaverProvider)(p.purchase.evidenceName ?? p.purchase.originalName ?? 'invoice-${p.importId}', data);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _readPayee() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(paymentsRepositoryProvider).readPayee(p.importId);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        _snack(data == null ? l10n.payPayeeNotFound : l10n.payPayeeFound(data.line));
        if (data != null) refreshPayments(ref, p.importId);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _editAccount() async {
    final id = p.supplierId;
    if (id == null) return;
    final payee = await showDialog<Payee?>(
      context: context,
      builder: (_) => _AccountDialog(initial: p.supplierAccount ?? p.payee, supplier: p.supplierName),
    );
    if (payee == null || !mounted) return;
    if (await _run(() => ref.read(paymentsRepositoryProvider).setSupplierAccount(id, payee.isEmpty ? null : payee))) {
      refreshPayments(ref, p.importId);
    }
  }

  String _of(int n, int all) => all == 0 ? '' : '$n/$all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final can = ref.watch(canRecordPaymentsProvider);
    final t = p.purchase;
    final id = p.importId;
    final st = p.steps;
    final states = p.stepStates;
    final steps = <OrderStep>[
      OrderStep(
        key: 'upload',
        title: l10n.ordStepUpload,
        state: states[OrderStepKind.upload]!,
        detail: [
          if (t.createdAt != null) _at.format(t.createdAt!),
          if (p.createdByName != null) p.createdByName!,
          t.originalName ?? '',
        ].where((x) => x.isNotEmpty).join(' · '),
        child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
          OutlinedButton.icon(
            key: ValueKey('pay-invoice-$id'),
            onPressed: _invoice,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: Text(l10n.payOpenInvoice),
          ),
          OutlinedButton.icon(
            key: ValueKey('pay-reading-$id'),
            onPressed: () => openReadingTable(context, ref, id),
            icon: const Icon(Icons.table_view_outlined, size: 18),
            label: Text(l10n.payOpenReading),
          ),
        ]),
      ),
      OrderStep(
        key: 'check',
        title: l10n.ordStepCheck,
        state: states[OrderStepKind.check]!,
        detail: st.read == 0 ? null : l10n.ordRows(_of(st.checked, st.read)),
      ),
      OrderStep(
        key: 'library',
        title: l10n.ordStepLibrary,
        state: states[OrderStepKind.library]!,
        detail: st.lines == 0 ? null : l10n.ordLines(_of(st.inLibrary, st.lines)),
      ),
      OrderStep(
        key: 'ai',
        title: l10n.ordStepAi,
        state: states[OrderStepKind.ai]!,
        detail: st.lines == 0 ? null : l10n.ordAiDetail(_of(st.named, st.lines), _of(st.weighed, st.lines)),
      ),
      OrderStep(
        key: 'stock',
        title: l10n.ordStepStock,
        state: states[OrderStepKind.stock]!,
        detail: p.inStock
            ? [if (p.stockAt != null) _at.format(p.stockAt!), l10n.ordLines(_of(st.inspected, st.lines))].join(' · ')
            : l10n.ordAwaiting(_of(st.inspected, st.lines)),
      ),
      OrderStep(
        key: 'payee',
        title: l10n.ordStepPayee,
        state: states[OrderStepKind.payee]!,
        detail: l10n.ordAmount(_yen.format(p.amount.round())),
        child: _payeeBlock(context, can),
      ),
      OrderStep(
        key: 'paid',
        title: l10n.ordStepPaid,
        state: states[OrderStepKind.paid]!,
        child: CheckboxListTile(
          key: ValueKey('pay-paid-$id'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: p.paid,
          onChanged: !can || _busy ? null : (v) => _setPaid(v ?? false),
          title: Text(l10n.calPaid),
          subtitle: Text(
            p.paid
                ? [if (p.paidAt != null) _at.format(p.paidAt!), if (p.paidByName != null) p.paidByName!].join(' · ')
                : l10n.payPaidHint,
            style: muted,
          ),
        ),
      ),
      OrderStep(
        key: 'proof',
        title: l10n.ordStepProof,
        state: states[OrderStepKind.proof]!,
        detail: l10n.payProofs(p.proofs.length),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final proof in p.proofs)
            ListTile(
              key: ValueKey('pay-proof-${proof.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(proof.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined),
              title: Text(proof.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [if (proof.createdAt != null) _at.format(proof.createdAt!), if (proof.createdByName != null) proof.createdByName!]
                    .join(' · '),
                style: muted,
              ),
              onTap: () => _openProof(proof),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  key: ValueKey('pay-proof-download-${proof.id}'),
                  tooltip: l10n.payDownload,
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => _downloadProof(proof),
                ),
                if (can)
                  IconButton(
                    key: ValueKey('pay-proof-remove-${proof.id}'),
                    tooltip: l10n.payProofRemove,
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _busy ? null : () => _removeProof(proof),
                  ),
              ]),
            ),
          if (can)
            TextButton.icon(
              key: ValueKey('pay-add-proof-$id'),
              onPressed: _busy ? null : _addProof,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(l10n.payAddProof),
            ),
        ]),
      ),
    ];
    final current = steps.indexWhere((s) => s.state != OrderStepState.done);
    return Card(
      key: ValueKey('pay-card-$id'),
      color: p.paid ? null : scheme.errorContainer.withValues(alpha: 0.18),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.supplierName.isEmpty ? l10n.txNoSupplier : p.supplierName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  [
                    l10n.payInvoiceDate(_day.format(t.day)),
                    if (t.docNumber != null) l10n.payInvoiceNo(t.docNumber!),
                    l10n.ivTitle(id),
                  ].join(' · '),
                  style: muted,
                ),
                const SizedBox(height: 2),
                Text(
                  current < 0 ? l10n.ordAllDone : l10n.ordNow(steps[current].title),
                  key: ValueKey('ord-now-$id'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: current < 0 ? scheme.primary : scheme.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('¥${_yen.format(p.amount.round())}',
                  key: ValueKey('pay-amount-$id'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(l10n.payTaxIncluded, style: muted),
            ]),
          ]),
          if (p.sameAs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _twinWarning(context),
          ],
          const SizedBox(height: AppSpacing.sm),
          // Closed: the steps as one bar; open: every step with what to do.
          Row(children: [
            Expanded(child: OrderFlowBar(states: [for (final s in steps) s.state], current: current, compact: true)),
            TextButton.icon(
              key: ValueKey('pay-toggle-$id'),
              onPressed: () => setState(() => _openCard = !_openCard),
              icon: Icon(_openCard ? Icons.expand_less : Icons.expand_more, size: 18),
              label: Text(_openCard ? l10n.ordClose : l10n.ordOpen),
            ),
          ]),
          if (_openCard) ...[
            const SizedBox(height: AppSpacing.sm),
            OrderTimeline(importId: id, steps: steps, current: current),
          ],
        ]),
      ),
    );
  }

  /// The same order may be in twice: which one, and why it looks so.
  Widget _twinWarning(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('pay-twin-${p.importId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.warning_amber_rounded, size: 20, color: theme.colorScheme.onTertiaryContainer),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final o in p.sameAs)
              Text(
                l10n.payTwin(
                  o.importId,
                  o.day == null ? '—' : _day.format(o.day!),
                  o.paid ? l10n.calPaid : l10n.calUnpaid,
                  [
                    if (o.sameFile) l10n.payTwinFile,
                    if (o.sameLines) l10n.payTwinLines,
                    if (o.sameInvoice) l10n.payTwinInvoice,
                  ].join('・'),
                ),
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onTertiaryContainer),
              ),
            Text(l10n.payTwinHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onTertiaryContainer)),
          ]),
        ),
      ]),
    );
  }

  Widget _payeeBlock(BuildContext context, bool can) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final payee = p.payee;
    final id = p.importId;
    return Container(
      key: ValueKey('pay-payee-$id'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.account_balance_outlined, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: payee == null
              ? Text(l10n.payNoPayee, key: ValueKey('pay-no-payee-$id'), style: theme.textTheme.bodyMedium)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    [payee.bank, payee.branch].whereType<String>().join(' '),
                    key: ValueKey('pay-bank-$id'),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Row(children: [
                    Text(
                      [payee.accountType, payee.accountNumber].whereType<String>().join(' '),
                      key: ValueKey('pay-account-$id'),
                      style: theme.textTheme.bodyMedium?.copyWith(fontFamily: AppFonts.mono),
                    ),
                    if (payee.accountNumber != null) CopyButton(value: payee.accountNumber!),
                  ]),
                  if (payee.holder != null) CopyableText(payee.holder!, style: theme.textTheme.bodyMedium),
                  Text(
                    switch (p.payeeSource) {
                      PayeeSource.invoice => l10n.payPayeeFromInvoice,
                      PayeeSource.supplier => l10n.payPayeeFromSupplier,
                      PayeeSource.none => '',
                    },
                    style: muted,
                  ),
                ]),
        ),
        if (can)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            TextButton.icon(
              key: ValueKey('pay-ai-payee-$id'),
              onPressed: _busy ? null : _readPayee,
              icon: const Icon(Icons.auto_awesome_outlined, size: 16),
              label: Text(l10n.payPayeeAi),
            ),
            if (p.supplierId != null)
              TextButton(
                key: ValueKey('pay-edit-payee-$id'),
                onPressed: _busy ? null : _editAccount,
                child: Text(payee == null ? l10n.payPayeeAdd : l10n.payPayeeEdit),
              ),
          ]),
      ]),
    );
  }
}

/// The supplier's 振込先, written or corrected by hand.
class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.initial, required this.supplier});

  final Payee? initial;
  final String supplier;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final _bank = TextEditingController(text: widget.initial?.bank ?? '');
  late final _branch = TextEditingController(text: widget.initial?.branch ?? '');
  late final _number = TextEditingController(text: widget.initial?.accountNumber ?? '');
  late final _holder = TextEditingController(text: widget.initial?.holder ?? '');
  late String? _type = widget.initial?.accountType;

  @override
  void dispose() {
    for (final c in [_bank, _branch, _number, _holder]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final types = {'普通', '当座', '貯蓄', if (_type != null) _type!};
    return AlertDialog(
      title: Text(l10n.payPayeeTitle(widget.supplier)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.payPayeeDialogHint, style: Theme.of(context).textTheme.bodySmall),
            TextField(key: const ValueKey('pay-f-bank'), controller: _bank, decoration: InputDecoration(labelText: l10n.payBank)),
            TextField(key: const ValueKey('pay-f-branch'), controller: _branch, decoration: InputDecoration(labelText: l10n.payBranch)),
            DropdownButtonFormField<String?>(
              key: const ValueKey('pay-f-type'),
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.payAccountType),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('—')),
                for (final t in types) DropdownMenuItem<String?>(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
            TextField(
              key: const ValueKey('pay-f-number'),
              controller: _number,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.payAccountNumber),
            ),
            TextField(key: const ValueKey('pay-f-holder'), controller: _holder, decoration: InputDecoration(labelText: l10n.payHolder)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('pay-f-save'),
          onPressed: () => Navigator.pop(
            context,
            Payee(bank: _v(_bank), branch: _v(_branch), accountType: _type, accountNumber: _v(_number), holder: _v(_holder)),
          ),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}


/// One step of an order's way: from the file to the proof of the transfer.
class OrderStep {
  const OrderStep({required this.key, required this.title, required this.state, this.detail, this.child});

  final String key;
  final String title;
  final OrderStepState state;
  final String? detail;
  final Widget? child;
}

/// An order's steps, top to bottom on one line: done ones ticked, the one it
/// is at marked, the rest open — to see at a glance how far it has gone.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.importId, required this.steps, required this.current});

  final int importId;
  final List<OrderStep> steps;

  /// The first step not done (-1 when all are).
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      key: ValueKey('ord-timeline-$importId'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, s) in steps.indexed)
          IntrinsicHeight(
            key: ValueKey('ord-step-$importId-${s.key}'),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 32,
                child: Column(children: [
                  Icon(
                    switch (s.state) {
                      OrderStepState.done => Icons.check_circle,
                      OrderStepState.partial => Icons.timelapse,
                      OrderStepState.todo => i == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    },
                    key: ValueKey('ord-mark-$importId-${s.key}-${s.state.name}'),
                    size: 22,
                    color: switch (s.state) {
                      OrderStepState.done => scheme.primary,
                      OrderStepState.partial => scheme.tertiary,
                      OrderStepState.todo => i == current ? scheme.tertiary : scheme.outline,
                    },
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: s.state == OrderStepState.done ? scheme.primary : scheme.outlineVariant,
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      '${i + 1}. ${s.title}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: i == current ? FontWeight.w800 : FontWeight.w600,
                        color: s.state == OrderStepState.todo && i != current ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                    if ((s.detail ?? '').isNotEmpty) Text(s.detail!, key: ValueKey('ord-detail-$importId-${s.key}'), style: muted),
                    if (s.child != null) ...[const SizedBox(height: 4), s.child!],
                  ]),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

/// An order's steps as one bar of numbered dots — done, under way, where it
/// is now, and what is left — with their names unless [compact].
class OrderFlowBar extends StatelessWidget {
  const OrderFlowBar({super.key, required this.states, required this.current, this.compact = false});

  final List<OrderStepState> states;

  /// The step it is at (-1 when all are done).
  final int current;
  final bool compact;

  static List<String> labels(AppLocalizations l10n) => [
        l10n.ordShortUpload, l10n.ordShortCheck, l10n.ordShortLibrary, l10n.ordShortAi,
        l10n.ordShortStock, l10n.ordShortPayee, l10n.ordShortPaid, l10n.ordShortProof,
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final names = labels(l10n);
    Color tone(int i) => switch (states[i]) {
          OrderStepState.done => scheme.primary,
          OrderStepState.partial => scheme.tertiary,
          OrderStepState.todo => i == current ? scheme.tertiary : scheme.outlineVariant,
        };
    return SingleChildScrollView(
      key: const ValueKey('ord-flow'),
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < states.length; i++) ...[
          if (i > 0) Container(width: compact ? 10 : 16, height: 2, color: tone(i - 1) == scheme.primary ? scheme.primary : scheme.outlineVariant),
          Tooltip(
            message: '${i + 1}. ${names[i]}',
            child: compact
                ? Container(
                    key: ValueKey('ord-dot-$i-${states[i].name}'),
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: states[i] == OrderStepState.done ? tone(i) : null,
                      border: Border.all(color: tone(i), width: i == current ? 2.5 : 1.5),
                    ),
                    child: states[i] == OrderStepState.done
                        ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                        : Text('${i + 1}', style: theme.textTheme.labelSmall?.copyWith(color: tone(i), fontWeight: FontWeight.w700)),
                  )
                : Container(
                    key: ValueKey('ord-chip-$i-${states[i].name}'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: i == current ? scheme.tertiaryContainer : null,
                      border: Border.all(color: tone(i), width: i == current ? 2 : 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        states[i] == OrderStepState.done
                            ? Icons.check_circle
                            : (states[i] == OrderStepState.partial ? Icons.timelapse : Icons.circle_outlined),
                        size: 14,
                        color: tone(i),
                      ),
                      const SizedBox(width: 4),
                      Text(names[i],
                          style: theme.textTheme.labelSmall?.copyWith(fontWeight: i == current ? FontWeight.w800 : FontWeight.w500)),
                    ]),
                  ),
          ),
        ],
      ]),
    );
  }
}
