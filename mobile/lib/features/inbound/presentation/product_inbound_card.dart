import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../evidence/domain/import_document.dart';
import '../../evidence/presentation/evidence_screen.dart';
import '../application/inbound_providers.dart';
import '../domain/inbound.dart';
import 'expected_receipt_screen.dart';
import 'inbound_labels.dart';

/// One product's place in 仕入先ファイル起点の入荷 (§46, §52): what each
/// supplier calls it, the names learned for matching, what is expected, every
/// receipt with its inspection, and the files behind them — all by product id.
class ProductInboundCard extends ConsumerWidget {
  const ProductInboundCard({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(productInboundHistoryProvider(productId));
    final h = async.valueOrNull;
    if (h == null) return const SizedBox.shrink();
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    DateTime? at(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
    void openPlan(Object? id) {
      final planId = id is num ? id.toInt() : int.tryParse('$id');
      if (planId == null) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpectedReceiptScreen(planId: planId)));
    }

    return Card(
      key: const ValueKey('product-inbound'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.ibProductHistory, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (h.isEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.ibNoHistory, style: muted),
            ],
            if (h.supplierNames.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.ibSupplierNames, style: theme.textTheme.labelLarge),
              for (final n in h.supplierNames)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    [
                      '${n['supplier_display_name'] ?? ''}「${n['supplier_name'] ?? ''}」',
                      if (n['supplier_code'] != null) '${n['supplier_code']}',
                      if (at(n['last_seen_at']) case final d?) l10n.ibLastSeen(ibDay(l10n, d)),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            if (h.aliases.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.ibAliases, style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
                for (final a in h.aliases)
                  for (final v in (a['values'] as List? ?? const []))
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(a['partner_name'] == null ? '$v' : '$v (${a['partner_name']})',
                          style: theme.textTheme.bodySmall),
                    ),
              ]),
            ],
            if (h.receipts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.ibReceiptsSection, style: theme.textTheme.labelLarge),
              for (final r in h.receipts)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      '${ibDayOrUndated(l10n, at(r['arrived_on']))}  ${r['supplier_name'] ?? ''}  ×${r['quantity'] ?? 0}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(switch (r['inspection']) {
                    final Map ins when '${ins['status']}' == 'PENDING' =>
                      '${l10n.ibInspectionPending} · ${l10n.ibInspectionScheduled(ibDayOrUndated(l10n, at(ins['scheduled_date'])))}',
                    final Map ins => l10n.ibInspectionPassFail(
                        (ins['passed'] as num?)?.toInt() ?? 0, (ins['failed'] as num?)?.toInt() ?? 0),
                    _ => '${r['delivery_number'] ?? ''}',
                  }, style: muted),
                  onTap: () => openPlan(r['plan_id']),
                ),
            ],
            if (h.expected.any((e) => ReceiptState.fromWire('${e['receipt_state']}').open)) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.ibOpenPlans, style: theme.textTheme.labelLarge),
              for (final e in h.expected.where((e) => ReceiptState.fromWire('${e['receipt_state']}').open))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${e['delivery_number'] ?? ''}  ${e['supplier_name'] ?? ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${l10n.ibExpectedOn(ibDayOrUndated(l10n, at(e['expected_arrival_date'])))} · '
                      '${l10n.ibPlanned} ${e['planned'] ?? 0} · ${l10n.ibReceivedQty} ${e['received'] ?? 0}',
                      style: muted),
                  trailing: ReceiptStatePill(ReceiptState.fromWire('${e['receipt_state']}')),
                  onTap: () => openPlan(e['plan_id']),
                ),
            ],
            if (h.documents.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.ibDocumentsSection, style: theme.textTheme.labelLarge),
              for (final d in h.documents)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined, size: 20),
                  title: Text('${d['file_name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      if (DocumentType.fromWire('${d['document_type']}') case final t?) documentTypeLabel(l10n, t),
                      if (d['supplier_name'] != null) '${d['supplier_name']}',
                    ].join(' · '),
                    style: muted,
                  ),
                  trailing: const Icon(Icons.download_outlined, size: 20),
                  onTap: () => downloadEvidence(context, ref, ImportDocument.fromJson(d)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
