import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/delivery_providers.dart';
import '../domain/receipt.dart';

/// Receipt history for one plan, with a cancel (訂正／取消) action. Cancelling a
/// receipt reverses the quantities it added to the plan and to stock, so a
/// mistaken or duplicated delivery can be undone instead of corrected by hand.
class ReceiptHistoryScreen extends ConsumerWidget {
  const ReceiptHistoryScreen({super.key, required this.planId});

  final int planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final receipts = ref.watch(planReceiptsProvider(planId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.receiptHistoryTitle)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(planReceiptsProvider(planId)),
        child: receipts.when(
          data: (items) {
            if (items.isEmpty) {
              return _ScrollableEmpty(
                icon: Icons.history,
                title: l10n.receiptEmpty,
                message: l10n.receiptEmptyBody,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _ReceiptCard(
                planId: planId,
                receipt: items[index],
              ),
            );
          },
          loading: () => LoadingView(message: l10n.loading),
          error: (error, _) => ErrorStateView(
            message: '$error',
            onRetry: () => ref.invalidate(planReceiptsProvider(planId)),
          ),
        ),
      ),
    );
  }
}

class _ReceiptCard extends ConsumerStatefulWidget {
  const _ReceiptCard({required this.planId, required this.receipt});

  final int planId;
  final Receipt receipt;

  @override
  ConsumerState<_ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends ConsumerState<_ReceiptCard> {
  bool _busy = false;

  Receipt get _r => widget.receipt;

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.receiptCancelQ),
        content: Text(l10n.receiptCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.receiptCancelAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(deliveryRepositoryProvider)
        .cancelReceipt(widget.planId, _r.id);
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (_) async {
        await HapticFeedback.mediumImpact();
        if (!mounted) return;
        ref.invalidate(planReceiptsProvider(widget.planId));
        ref.invalidate(deliveryPlansProvider);
        ref.invalidate(deliveryPlanDetailProvider(widget.planId));
        ref.invalidate(stockListProvider);
        _snack(l10n.receiptCancelledDone, tone: StatusTone.success);
      },
      failure: (f) => _snack(f.message, tone: StatusTone.danger),
    );
  }

  void _snack(String message, {StatusTone tone = StatusTone.neutral}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final (icon, bg) = switch (tone) {
      StatusTone.success => (Icons.check_circle, scheme.inverseSurface),
      StatusTone.danger => (Icons.error_outline, scheme.error),
      _ => (Icons.info_outline, scheme.inverseSurface),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(icon, size: 20, color: scheme.onInverseSurface),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: bg,
      ));
  }

  String _stamp(DateTime? d) {
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cancelled = _r.isCancelled;

    final meta = [
      l10n.planPreviewCount(_r.lineCount, _r.totalUnits),
      _stamp(_r.createdAt),
    ].where((s) => s.isNotEmpty).join('  ·  ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusAvatar(
                  tone: cancelled ? StatusTone.neutral : StatusTone.success,
                  icon: cancelled ? Icons.block : Icons.inventory_2_outlined,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _r.referenceNo ?? '#${_r.id}',
                        style: theme.textTheme.titleSmall?.copyWith(
                            fontFamily: 'FiraCode',
                            decoration:
                                cancelled ? TextDecoration.lineThrough : null,
                            color: cancelled ? scheme.onSurfaceVariant : null),
                      ),
                      const SizedBox(height: 2),
                      Text(meta,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                      if (_r.noteReference != null &&
                          _r.noteReference!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('${l10n.reconNoteReference}: ${_r.noteReference}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                if (cancelled)
                  StatusPill(
                    tone: StatusTone.neutral,
                    label: l10n.receiptCancelledBadge,
                    icon: Icons.block,
                    dense: true,
                  ),
              ],
            ),
            if (!cancelled) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _cancel,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.undo, color: scheme.error),
                  label: Text(l10n.receiptCancelAction,
                      style: TextStyle(color: scheme.error)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScrollableEmpty extends StatelessWidget {
  const _ScrollableEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: EmptyStateView(icon: icon, title: title, message: message),
        ),
      ),
    );
  }
}
