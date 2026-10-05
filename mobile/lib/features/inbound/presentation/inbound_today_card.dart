import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/inbound_providers.dart';
import 'expected_receipt_screen.dart';
import 'inbound_labels.dart';

/// 今日の入荷 (§28): what is due, what waits for inspection and what waits to
/// be put away in the current warehouse, for the floor. Nothing is shown
/// until a warehouse is picked, or when the counts cannot be read.
class InboundTodayCard extends ConsumerWidget {
  const InboundTodayCard({super.key, this.onOpenFeature});

  /// Opens a menu entry by id (delivery / inspection / putaway).
  final void Function(String id)? onOpenFeature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(inboundTodayProvider).valueOrNull;
    if (today == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget tile(String key, String label, int n, IconData icon, String? feature, {String? note}) => Expanded(
          child: InkWell(
            key: ValueKey('inbound-today-$key'),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            onTap: feature == null || onOpenFeature == null ? null : () => onOpenFeature!(feature),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(height: AppSpacing.xs),
                Text('$n', style: theme.textTheme.headlineSmall?.copyWith(fontFamily: AppFonts.mono)),
                Text(label, style: theme.textTheme.bodySmall),
                if (note != null)
                  Text(note, style: theme.textTheme.bodySmall?.copyWith(color: scheme.tertiary)),
              ]),
            ),
          ),
        );

    return Card(
      key: const ValueKey('inbound-today'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.ibTodayTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            tile('due', l10n.ibTodayDue, today.dueToday, Icons.local_shipping_outlined, 'delivery',
                note: [
                  if (today.overdue > 0) '${l10n.ibTodayOverdue} ${today.overdue}',
                  if (today.undated > 0) '${l10n.ibTodayUndated} ${today.undated}',
                ].join(' · ').ifEmpty),
            tile('inspection', l10n.ibTodayAwaitingInspection, today.awaitingInspection,
                Icons.fact_check_outlined, 'inspection'),
            tile('putaway', l10n.ibTodayPutaway, today.putawayWaiting, Icons.move_to_inbox_outlined, 'putaway'),
          ]),
          if (today.plans.isEmpty)
            Text(l10n.ibTodayEmpty, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))
          else
            for (final p in today.plans.take(5))
              ListTile(
                key: ValueKey('inbound-today-plan-${p.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${p.deliveryNumber}  ${p.supplierName ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${l10n.ibExpectedOn(ibDayOrUndated(l10n, p.expected))} · ${l10n.ibRemaining} ${p.remaining}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: p.expected != null && today.plans.isNotEmpty && p.expected!.isBefore(DateUtils.dateOnly(DateTime.now()))
                            ? scheme.error
                            : null)),
                trailing: ReceiptStatePill(p.state),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ExpectedReceiptScreen(planId: p.id))),
              ),
        ]),
      ),
    );
  }
}

extension on String {
  String? get ifEmpty => isEmpty ? null : this;
}
