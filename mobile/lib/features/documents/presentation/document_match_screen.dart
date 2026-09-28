import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/documents_providers.dart';
import '../domain/documents.dart';
import 'documents_labels.dart';
import 'invoice_editor_screen.dart';

/// 書類照合 (spec §51): one purchase order laid against the supplier's
/// invoices, the delivery notes, what was received and what inspection
/// found — product by product, every difference flagged. The invoice is
/// settled by a person (§43), never automatically.
class DocumentMatchScreen extends ConsumerWidget {
  const DocumentMatchScreen({super.key, required this.purchaseOrderId});

  final int purchaseOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(documentMatchProvider(purchaseOrderId));
    final canManage = ref.watch(documentsCanManageProvider);
    return Scaffold(
      appBar: AppBar(title: Text('${l10n.docMatchTitle} ${async.valueOrNull?.poNumber ?? ''}')),
      floatingActionButton: canManage && async.hasValue
          ? FloatingActionButton.extended(
              key: const ValueKey('doc-add-invoice'),
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => InvoiceEditorScreen(purchaseOrderId: purchaseOrderId, supplierName: async.value!.supplierName),
                ));
                if (saved == true) _refresh(ref);
              },
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(l10n.docAddInvoice),
            )
          : null,
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => _refresh(ref)),
        data: (m) => RefreshIndicator(
          onRefresh: () async => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
            children: [
              _Header(match: m, canManage: canManage),
              const SizedBox(height: AppSpacing.md),
              for (final line in m.lines) _LineCard(line: line),
              const SizedBox(height: AppSpacing.md),
              _Invoices(purchaseOrderId: purchaseOrderId, canManage: canManage),
            ],
          ),
        ),
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(documentMatchProvider(purchaseOrderId));
    ref.invalidate(purchaseOrderInvoicesProvider(purchaseOrderId));
    ref.invalidate(documentExceptionsProvider);
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.match, required this.canManage});

  final DocumentMatch match;
  final bool canManage;

  Future<void> _tolerance(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final qty = TextEditingController(text: docNum(match.qtyTolerancePct));
    final price = TextEditingController(text: docNum(match.priceTolerancePct));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.docTolerance),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(key: const ValueKey('doc-tol-qty'), controller: qty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l10n.docToleranceQty, suffixText: '%')),
          TextField(key: const ValueKey('doc-tol-price'), controller: price, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l10n.docTolerancePrice, suffixText: '%')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('doc-tol-save'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.actionSave)),
        ],
      ),
    );
    if (ok != true || match.supplierId == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final r = await ref.read(documentsRepositoryProvider).setTolerance(
        match.supplierId!, double.tryParse(qty.text.trim()) ?? 0, double.tryParse(price.text.trim()) ?? 0);
    r.when(
      success: (_) => ref.invalidate(documentMatchProvider(match.purchaseOrderId)),
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = match;
    Widget step(IconData icon, String label, String sub) => Column(children: [
          Icon(icon, color: theme.colorScheme.primary),
          Text(label, style: theme.textTheme.labelMedium),
          Text(sub, style: theme.textTheme.bodySmall),
        ]);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(m.supplierName ?? '', style: theme.textTheme.titleMedium)),
              StatusPill(key: const ValueKey('doc-match-status'), tone: matchStatusTone(m.status), label: matchStatusLabel(l10n, m.status)),
            ]),
            const SizedBox(height: AppSpacing.md),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              step(Icons.add_shopping_cart_outlined, l10n.docOrder, m.poNumber ?? ''),
              const Icon(Icons.arrow_forward, size: 16),
              step(Icons.receipt_long_outlined, l10n.docInvoice, '${m.invoices.length}'),
              const Icon(Icons.arrow_forward, size: 16),
              step(Icons.local_shipping_outlined, l10n.docDelivery, '${m.deliveries.length}'),
              const Icon(Icons.arrow_forward, size: 16),
              step(Icons.fact_check_outlined, l10n.docInspection, ''),
            ]),
            const SizedBox(height: AppSpacing.md),
            Wrap(spacing: AppSpacing.lg, runSpacing: AppSpacing.xs, children: [
              Text('${l10n.docOrderAmount} ¥${docNum(m.poAmount)}'),
              Text('${l10n.docInvoiceAmount} ¥${docNum(m.invoiceLinesAmount)}'),
              Text('${l10n.docDifference} ${m.amountDifference >= 0 ? '+' : ''}¥${docNum(m.amountDifference)}',
                  key: const ValueKey('doc-amount-diff'),
                  style: TextStyle(color: m.amountDifference.abs() >= 0.5 ? theme.colorScheme.error : null, fontWeight: FontWeight.w600)),
            ]),
            TextButton.icon(
              key: const ValueKey('doc-tolerance'),
              onPressed: canManage && m.supplierId != null ? () => _tolerance(context, ref) : null,
              icon: const Icon(Icons.tune, size: 16),
              label: Text('${l10n.docTolerance}: ${l10n.docToleranceQty} ${docNum(m.qtyTolerancePct)}% / ${l10n.docTolerancePrice} ${docNum(m.priceTolerancePct)}%'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line});

  final MatchLine line;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final l = line;
    Widget cell(String label, String value, {bool bad = false}) => Expanded(
          child: Column(children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text(value, style: theme.textTheme.titleSmall?.copyWith(color: bad ? theme.colorScheme.error : null)),
          ]),
        );
    return Card(
      key: ValueKey('doc-line-${l.key}'),
      color: l.ok ? null : theme.colorScheme.errorContainer.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(l.ok ? Icons.check_circle : Icons.warning_amber_rounded, size: 18, color: l.ok ? Colors.green : theme.colorScheme.error),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(l.productName ?? l.janCode ?? '', style: theme.textTheme.titleSmall)),
              if (l.janCode != null) Text(l.janCode!, style: theme.textTheme.bodySmall),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              cell(l10n.docOrder, docNum(l.ordered)),
              cell(l10n.docInvoice, docNum(l.invoiced), bad: l.flags.contains('invoice_qty') || l.flags.contains('not_ordered')),
              cell(l10n.docDelivery, docNum(l.delivered)),
              cell(l10n.docReceived, docNum(l.received), bad: l.flags.contains('short_delivery')),
              cell(l10n.docInspection, l.failed > 0 ? '${docNum(l.inspected)} (${l10n.docFailedShort(docNum(l.failed))})' : docNum(l.inspected),
                  bad: l.flags.contains('inspect_short') || l.failed > 0),
            ]),
            if (l.orderPrice != null || l.invoicePrice != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  '${l10n.docUnitPrice}: ${l10n.docOrder} ${l.orderPrice == null ? '—' : '¥${docNum(l.orderPrice!)}'} / ${l10n.docInvoice} ${l.invoicePrice == null ? '—' : '¥${docNum(l.invoicePrice!)}'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: l.flags.contains('invoice_price') ? theme.colorScheme.error : null),
                ),
              ),
            if (l.flags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              DocFlagChips(flags: l.flags),
            ],
          ],
        ),
      ),
    );
  }
}

class _Invoices extends ConsumerWidget {
  const _Invoices({required this.purchaseOrderId, required this.canManage});

  final int purchaseOrderId;
  final bool canManage;

  Future<void> _set(BuildContext context, WidgetRef ref, SupplierInvoice inv, InvoiceStatus status) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final r = await ref.read(documentsRepositoryProvider).setStatus(inv.id!, status);
    r.when(
      success: (terms) {
        ref.invalidate(purchaseOrderInvoicesProvider(purchaseOrderId));
        ref.invalidate(documentMatchProvider(purchaseOrderId));
        ref.invalidate(documentExceptionsProvider);
        if (status == InvoiceStatus.approved) messenger.showSnackBar(SnackBar(content: Text(l10n.docApproved(terms))));
      },
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ref.watch(purchaseOrderInvoicesProvider(purchaseOrderId)).when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(humanizeApiErrorMessage(l10n, '$e')),
          data: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.docInvoices, style: theme.textTheme.titleSmall),
              if (rows.isEmpty) Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(l10n.docNoInvoices)),
              for (final inv in rows)
                Card(
                  key: ValueKey('doc-invoice-${inv.id}'),
                  child: ListTile(
                    title: Text(inv.invoiceNumber),
                    subtitle: Text([
                      if (inv.invoiceDate != null) inv.invoiceDate!,
                      '${inv.lineCount}${l10n.docLinesSuffix}',
                      if (inv.total != null) '¥${docNum(inv.total!)}',
                      if (inv.source == 'document') l10n.docReadFromDocument,
                    ].join(' · ')),
                    leading: StatusPill(tone: invoiceStatusTone(inv.status), label: invoiceStatusLabel(l10n, inv.status), dense: true),
                    onTap: inv.settled || !canManage
                        ? null
                        : () async {
                            final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
                              builder: (_) => InvoiceEditorScreen(purchaseOrderId: purchaseOrderId, invoiceId: inv.id),
                            ));
                            if (saved == true) {
                              ref.invalidate(purchaseOrderInvoicesProvider(purchaseOrderId));
                              ref.invalidate(documentMatchProvider(purchaseOrderId));
                            }
                          },
                    trailing: canManage && !inv.settled
                        ? Wrap(children: [
                            IconButton(
                              key: ValueKey('doc-approve-${inv.id}'),
                              tooltip: l10n.docApprove,
                              icon: const Icon(Icons.verified_outlined),
                              onPressed: () => _set(context, ref, inv, InvoiceStatus.approved),
                            ),
                            IconButton(
                              tooltip: l10n.docVoid,
                              icon: const Icon(Icons.block),
                              onPressed: () => _set(context, ref, inv, InvoiceStatus.voided),
                            ),
                          ])
                        : null,
                  ),
                ),
            ],
          ),
        );
  }
}
