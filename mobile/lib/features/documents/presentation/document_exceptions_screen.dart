import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/documents_providers.dart';
import '../domain/documents.dart';
import 'document_match_screen.dart';
import 'documents_labels.dart';

/// 書類の差異 (spec §53): every difference between order, invoice, delivery
/// and inspection on recent orders — short, one line each, biggest first —
/// so normal data passes and a person only looks at the exceptions (§49).
class DocumentExceptionsScreen extends ConsumerWidget {
  const DocumentExceptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.docExceptionsTitle)),
      body: ref.watch(documentExceptionsProvider).when(
            loading: () => LoadingView(message: l10n.loading),
            error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(documentExceptionsProvider)),
            data: (rows) {
              if (rows.isEmpty) {
                return EmptyStateView(icon: Icons.verified_outlined, title: l10n.docNoExceptions);
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(documentExceptionsProvider),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(l10n.docExceptionCount(rows.length), style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < rows.length; i++) _Row(row: rows[i], index: i),
                  ],
                ),
              );
            },
          ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.index});

  final DocumentException row;
  final int index;

  String _delta(AppLocalizations l10n) => switch (row.kind) {
        'invoice_qty' => l10n.docDeltaQty(docNum(row.invoiced - row.ordered)),
        'short_delivery' => l10n.docDeltaQty(docNum(row.received - row.invoiced)),
        'inspect_short' => l10n.docDeltaQty(docNum(row.inspected - row.received)),
        'defective' => l10n.docFailedShort(docNum(row.failed)),
        'invoice_price' => l10n.docDeltaPrice(
            '${(row.invoicePrice ?? 0) - (row.orderPrice ?? 0) >= 0 ? '+' : ''}${docNum((row.invoicePrice ?? 0) - (row.orderPrice ?? 0))}'),
        'not_ordered' => l10n.docDeltaQty(docNum(row.invoiced > 0 ? row.invoiced : row.received)),
        'not_invoiced' => l10n.docDeltaQty(docNum(-row.ordered)),
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('doc-exception-$index'),
      child: ListTile(
        leading: StatusPill(tone: docFlagTone(row.kind), label: docFlagLabel(l10n, row.kind), dense: true),
        title: Text('${row.poNumber ?? ''}  ${row.productName ?? row.janCode ?? ''}'),
        subtitle: Text(row.supplierName ?? ''),
        trailing: Text(_delta(l10n), style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocumentMatchScreen(purchaseOrderId: row.purchaseOrderId))),
      ),
    );
  }
}
