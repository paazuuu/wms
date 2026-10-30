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
  const PaymentsScreen({super.key, this.today});

  /// For tests: the month the month view starts on.
  final DateTime? today;

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  late DateTime _month = DateTime((widget.today ?? DateTime.now()).year, (widget.today ?? DateTime.now()).month);
  bool _unpaid = true;

  PaymentsRange get _range => _unpaid ? const UnpaidPayments() : MonthPayments(_month.year, _month.month);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(paymentsProvider(_range));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featPayments)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(l10n.payIntro, style: muted),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ChoiceChip(
              key: const ValueKey('pay-unpaid'),
              label: Text(l10n.payUnpaidAll),
              selected: _unpaid,
              onSelected: (_) => setState(() => _unpaid = true),
            ),
            ChoiceChip(
              key: const ValueKey('pay-by-month'),
              label: Text(l10n.payByMonth),
              selected: !_unpaid,
              onSelected: (_) => setState(() => _unpaid = false),
            ),
            if (!_unpaid) ...[
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
              if (all.isEmpty) return [Text(_unpaid ? l10n.payNoneUnpaid : l10n.payNone, key: const ValueKey('pay-none'))];
              final unpaid = all.where((p) => !p.paid);
              final due = unpaid.fold<double>(0, (s, p) => s + p.amount);
              return [
                Text(
                  l10n.paySummary(all.length, unpaid.length, _yen.format(due.round())),
                  key: const ValueKey('pay-summary'),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final p in all) PaymentCard(payment: p),
              ];
            },
          ),
        ],
      ),
    );
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
  const PaymentCard({super.key, required this.payment});

  final Payment payment;

  @override
  ConsumerState<PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends ConsumerState<PaymentCard> {
  bool _busy = false;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final can = ref.watch(canRecordPaymentsProvider);
    final t = p.purchase;
    final id = p.importId;
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
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('¥${_yen.format(p.amount.round())}',
                  key: ValueKey('pay-amount-$id'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(l10n.payTaxIncluded, style: muted),
            ]),
          ]),
          const SizedBox(height: AppSpacing.sm),
          _payeeBlock(context, can),
          const SizedBox(height: AppSpacing.xs),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
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
          const Divider(height: AppSpacing.lg),
          CheckboxListTile(
            key: ValueKey('pay-paid-$id'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: p.paid,
            onChanged: !can || _busy ? null : (v) => _setPaid(v ?? false),
            title: Text(l10n.calPaid),
            subtitle: Text(
              p.paid
                  ? [
                      if (p.paidAt != null) _at.format(p.paidAt!),
                      if (p.paidByName != null) p.paidByName!,
                    ].join(' · ')
                  : l10n.payPaidHint,
              style: muted,
            ),
          ),
          Text(l10n.payProofs(p.proofs.length), style: theme.textTheme.titleSmall),
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
              trailing: can
                  ? IconButton(
                      key: ValueKey('pay-proof-remove-${proof.id}'),
                      tooltip: l10n.payProofRemove,
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _busy ? null : () => _removeProof(proof),
                    )
                  : null,
            ),
          if (can)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('pay-add-proof-$id'),
                onPressed: _busy ? null : _addProof,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(l10n.payAddProof),
              ),
            ),
        ]),
      ),
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
        if (can && p.supplierId != null)
          TextButton(
            key: ValueKey('pay-edit-payee-$id'),
            onPressed: _busy ? null : _editAccount,
            child: Text(payee == null ? l10n.payPayeeAdd : l10n.payPayeeEdit),
          ),
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
