import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/purchase_order_providers.dart';
import '../domain/purchase_order.dart';

final _candidatesProvider = FutureProvider.autoDispose
    .family<List<PurchaseLinkCandidate>, int>((ref, lineId) async {
  final result = await ref.watch(purchaseOrderRepositoryProvider).linkCandidates(lineId);
  return result.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// Which orders one purchase-order line is for, changed by hand after the
/// order exists: add an order, move quantity from one to another, or take a
/// link away. What the links do not add up to is bought ahead (見込み).
///
/// Moving a link after the goods arrived moves the promise too — the server
/// gives back what this purchase had promised to an order that lost its link
/// and promises the arrived goods to the new one. Pops true once saved.
class PurchaseLinkEditorPage extends ConsumerWidget {
  const PurchaseLinkEditorPage({super.key, required this.line});

  final PurchaseOrderLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(_candidatesProvider(line.id));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.poLinkEditTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(_candidatesProvider(line.id)),
        ),
        data: (candidates) => _Editor(line: line, candidates: candidates),
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.line, required this.candidates});

  final PurchaseOrderLine line;
  final List<PurchaseLinkCandidate> candidates;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final Map<int, TextEditingController> _qty = {
    for (final c in widget.candidates)
      c.salesOrderLineId: TextEditingController(text: c.linked > 0 ? '${c.linked}' : ''),
  };
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _of(int id) => int.tryParse(_qty[id]?.text.trim() ?? '') ?? 0;

  int get _total => widget.candidates.fold(0, (s, c) => s + _of(c.salesOrderLineId));

  String? _candidateError(AppLocalizations l10n, PurchaseLinkCandidate c) =>
      _of(c.salesOrderLineId) > c.ordered ? l10n.poLinkOverOrdered(c.ordered) : null;

  bool get _valid {
    final l10n = AppLocalizations.of(context);
    return _total <= widget.line.quantity &&
        widget.candidates.every((c) => _candidateError(l10n, c) == null);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final result = await ref.read(purchaseOrderRepositoryProvider).setLineDemands(
      widget.line.id,
      [
        for (final c in widget.candidates)
          (salesOrderLineId: c.salesOrderLineId, quantity: _of(c.salesOrderLineId)),
      ],
    );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (r) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(l10n.poLinkSaved(r.linkedUnits, r.reservedUnits, r.releasedUnits)),
          ));
        Navigator.pop(context, true);
      },
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(humanizeApiErrorMessage(l10n, f.message)),
          backgroundColor: Theme.of(context).colorScheme.error,
        )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = widget.line;
    final ahead = line.quantity - _total;
    final over = _total > line.quantity;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(line.productName.isNotEmpty ? line.productName : line.janCode,
                  style: theme.textTheme.titleMedium),
              Text(l10n.poLinkLineSummary(line.quantity, line.received),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.poLinkHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              if (widget.candidates.isEmpty)
                Text(l10n.poLinkNoCandidates,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              for (final c in widget.candidates)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [c.soNumber ?? '#${c.salesOrderId}', c.customerName]
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _candidateError(l10n, c) ??
                                    l10n.poLinkCandidateStatus(
                                        c.ordered, c.promised, c.backordered, c.onOrder),
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: _candidateError(l10n, c) != null ? scheme.error : null),
                              ),
                              if (c.filled > 0)
                                Text(l10n.poLinkFilled(c.filled),
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: scheme.primary)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 88,
                          child: TextField(
                            key: ValueKey('po-link-edit-${c.salesOrderLineId}'),
                            controller: _qty[c.salesOrderLineId],
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textAlign: TextAlign.end,
                            decoration: InputDecoration(
                                labelText: l10n.poLinkQuantity, hintText: '0'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  over
                      ? l10n.demandPoOverLinked(_total, line.quantity)
                      : l10n.demandPoRowSummary(_total, ahead),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: over ? scheme.error : null),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.minTouch,
                  child: FilledButton(
                    onPressed: _busy || !_valid ? null : _save,
                    child: Text(l10n.actionSave),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
