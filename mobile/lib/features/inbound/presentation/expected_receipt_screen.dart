import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../delivery/presentation/reconciliation_screen.dart';
import '../../evidence/domain/import_document.dart';
import '../../evidence/presentation/evidence_screen.dart';
import '../application/inbound_providers.dart';
import '../domain/inbound.dart';
import 'inbound_labels.dart';

/// 入荷予定の詳細 (§17): what the supplier said would come and when, every
/// delivery that came against it (分納) with its own inspection, the files
/// behind it and how its dates moved (§25). Receiving starts from here.
class ExpectedReceiptScreen extends ConsumerWidget {
  const ExpectedReceiptScreen({super.key, required this.planId});

  final int planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(expectedReceiptProvider(planId));
    return Scaffold(
      appBar: AppBar(title: Text(async.valueOrNull?.deliveryNumber ?? l10n.ibDetailTitle)),
      body: async.when(
        data: (r) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(expectedReceiptProvider(planId)),
          child: _Body(receipt: r),
        ),
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: humanizeApiErrorMessage(l10n, '$e'),
          onRetry: () => ref.invalidate(expectedReceiptProvider(planId)),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.receipt});

  final ExpectedReceipt receipt;

  Future<void> _save(BuildContext context, WidgetRef ref, Map<String, dynamic> changes) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final r = await ref.read(inboundRepositoryProvider).setExpectedReceipt(receipt.id, changes);
    switch (r) {
      case ApiSuccess():
        ref.invalidate(expectedReceiptProvider(receipt.id));
        ref.invalidate(deliveryPlansProvider);
        ref.invalidate(inboundTodayProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.ibDatesSaved)));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  Future<void> _pickDay(BuildContext context, WidgetRef ref, String key, DateTime? current) async {
    final picked = await pickPlannedDay(context, current, today: receipt.today);
    if (picked == null || !context.mounted) return;
    await _save(context, ref, {key: picked.date == null ? null : isoDay(picked.date!)});
  }

  Future<void> _moveInspection(BuildContext context, WidgetRef ref, ReceiptInspection ins) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final base = DateUtils.dateOnly(receipt.today ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: ins.scheduledDate ?? base,
      firstDate: base.subtract(const Duration(days: 365)),
      lastDate: base.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    final r = await ref.read(inboundRepositoryProvider).setInspectionSchedule(ins.id, picked);
    switch (r) {
      case ApiSuccess():
        ref.invalidate(expectedReceiptProvider(receipt.id));
        messenger.showSnackBar(SnackBar(content: Text(l10n.ibDatesSaved)));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(authControllerProvider).user;
    final canEdit = user?.hasPermission('receiving.confirm') ?? false;
    final canInspect = canEdit || (user?.hasPermission('inspection.confirm') ?? false);
    final r = receipt;
    final open = r.receiptState != ReceiptState.cancelled && r.receiptState != ReceiptState.closed;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    Widget dateRow(String key, String label, DateTime? value, IconData icon) => ListTile(
          key: ValueKey('er-$key'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(ibDayOrUndated(l10n, value),
              style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: AppFonts.mono, color: value == null ? scheme.onSurfaceVariant : null)),
          trailing: canEdit && open ? const Icon(Icons.edit_calendar_outlined) : null,
          onTap: canEdit && open ? () => _pickDay(context, ref, key, value) : null,
        );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(r.supplierName ?? l10n.unknownSupplier, style: theme.textTheme.titleMedium),
                  ),
                  ReceiptStatePill(r.receiptState, dense: false),
                ]),
                if (r.referenceNo != null || r.warehouseName != null)
                  Text([if (r.referenceNo != null) r.referenceNo!, if (r.warehouseName != null) r.warehouseName!]
                      .join(' · '), style: muted),
                const SizedBox(height: AppSpacing.sm),
                Text(ibTotals(l10n, planned: r.planned, received: r.received, remaining: r.remaining),
                    key: const ValueKey('er-totals'),
                    style: theme.textTheme.titleSmall?.copyWith(fontFamily: AppFonts.mono)),
                const Divider(height: AppSpacing.xl),
                dateRow('expected_arrival_date', l10n.ibExpectedArrival, r.expectedArrivalDate, Icons.local_shipping_outlined),
                dateRow('scheduled_inspection_date', l10n.ibScheduledInspection, r.scheduledInspectionDate,
                    Icons.fact_check_outlined),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<DocumentType?>(
                      key: const ValueKey('er-document-type'),
                      initialValue: r.documentType,
                      decoration: InputDecoration(labelText: l10n.ibDocType, isDense: true),
                      items: [
                        DropdownMenuItem<DocumentType?>(value: null, child: Text(l10n.ibUndated)),
                        for (final t in DocumentType.values)
                          DropdownMenuItem(value: t, child: Text(documentTypeLabel(l10n, t))),
                      ],
                      onChanged: canEdit && open ? (t) => _save(context, ref, {'document_type': t?.wire}) : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  if (canEdit && (open || r.onHold))
                    TextButton.icon(
                      key: const ValueKey('er-hold'),
                      onPressed: () => _save(context, ref, {'on_hold': !r.onHold}),
                      icon: Icon(r.onHold ? Icons.play_circle_outline : Icons.pause_circle_outline),
                      label: Text(r.onHold ? l10n.ibUnhold : l10n.ibHold),
                    ),
                ]),
                if (r.documentType == DocumentType.invoice) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.ibInvoiceNote, style: muted?.copyWith(color: scheme.tertiary)),
                ],
              ],
            ),
          ),
        ),
        if (open && canEdit) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: AppSpacing.minTouch,
            child: FilledButton.icon(
              key: const ValueKey('er-receive'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReconciliationScreen(planId: r.id),
              )),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l10n.ibReceiveAction),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _Section(l10n.ibLinesSection),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final (i, l) in r.lines.indexed) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                key: ValueKey('er-line-${l.id}'),
                title: Text(l.productName.isEmpty ? l.janCode : l.productName,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (l.supplierProductName != null && l.supplierProductName != l.productName)
                    Text(l10n.importSupplierWriting(l.supplierProductName!), style: muted, maxLines: 2),
                  Text(ibTotals(l10n, planned: l.planned, received: l.received, remaining: l.remaining)
                      + (l.over > 0 ? ' · ${l10n.ibOverQty(l.over)}' : ''),
                      style: theme.textTheme.bodySmall?.copyWith(fontFamily: AppFonts.mono)),
                ]),
                trailing: ReceiptStatePill(l.state),
              ),
            ],
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Section(l10n.ibReceiptsSection),
        if (r.receipts.isEmpty)
          Text(l10n.ibNoReceipts, style: muted)
        else
          for (final rc in r.receipts)
            Card(
              key: ValueKey('er-receipt-${rc.id}'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        rc.cancelled ? '${l10n.ibReceiptSeq(rc.seq)} (${l10n.ibStateCancelled})' : l10n.ibReceiptSeq(rc.seq),
                        style: theme.textTheme.titleSmall?.copyWith(
                            decoration: rc.cancelled ? TextDecoration.lineThrough : null),
                      ),
                    ),
                    Text('${l10n.ibArrivedOn} ${ibDayOrUndated(l10n, rc.arrivedOn)}',
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: AppFonts.mono)),
                  ]),
                  for (final l in rc.lines)
                    Text('${l.productName.isEmpty ? l.janCode : l.productName}  ×${l.quantity}',
                        style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (rc.inspection case final ins?) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(spacing: AppSpacing.md, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(ins.pending ? l10n.ibInspectionPending : l10n.ibInspectionDone,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600, color: ins.pending ? scheme.tertiary : scheme.primary)),
                      Text(l10n.ibInspectionScheduled(ibDayOrUndated(l10n, ins.scheduledDate)), style: muted),
                      if (ins.startedAt != null) Text(l10n.ibInspectionStarted(ibDateTime(ins.startedAt!)), style: muted),
                      if (ins.completedAt != null)
                        Text(l10n.ibInspectionCompleted(ibDateTime(ins.completedAt!)), style: muted),
                      if (!ins.pending) Text(l10n.ibInspectionPassFail(ins.passed, ins.failed), style: muted),
                      if (ins.pending && canInspect)
                        TextButton(
                          key: ValueKey('er-move-inspection-${ins.id}'),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: () => _moveInspection(context, ref, ins),
                          child: Text(l10n.ibMoveInspection),
                        ),
                    ]),
                  ],
                ]),
              ),
            ),
        const SizedBox(height: AppSpacing.lg),
        _Section(l10n.ibDocumentsSection),
        if (r.documents.isEmpty)
          Text(l10n.ibNoDocuments, style: muted)
        else
          Card(
            child: Column(children: [
              for (final d in r.documents)
                ListTile(
                  key: ValueKey('er-doc-${d['id']}'),
                  leading: const Icon(Icons.description_outlined),
                  title: Text('${d['file_name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      if (DocumentType.fromWire('${d['document_type']}') case final t?) documentTypeLabel(l10n, t),
                      if (DateTime.tryParse('${d['uploaded_at']}') case final at?) ibDateTime(at.toLocal()),
                    ].join(' · '),
                    style: muted,
                  ),
                  trailing: const Icon(Icons.download_outlined),
                  onTap: () => downloadEvidence(context, ref, ImportDocument.fromJson(d)),
                ),
            ]),
          ),
        const SizedBox(height: AppSpacing.lg),
        _Section(l10n.ibHistorySection),
        Card(
          child: Column(children: [
            for (final e in r.history.reversed)
              ListTile(
                dense: true,
                leading: Text(ibDateTime(e.at), style: theme.textTheme.bodySmall?.copyWith(fontFamily: AppFonts.mono)),
                title: Text(inboundEventLabel(l10n, e)),
                subtitle: e.actor == null ? null : Text(e.actor!, style: muted),
              ),
          ]),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      );
}
