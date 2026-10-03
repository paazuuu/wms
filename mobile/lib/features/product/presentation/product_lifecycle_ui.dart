import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/product.dart';

/// A lifecycle's name, as the library shows it (0120).
String lifecycleLabel(AppLocalizations l10n, ProductLifecycle l) => switch (l) {
      ProductLifecycle.active => l10n.lifecycleActive,
      ProductLifecycle.dormant => l10n.lifecycleDormant,
      ProductLifecycle.discontinued => l10n.lifecycleDiscontinued,
      ProductLifecycle.archived => l10n.lifecycleArchived,
    };

/// What the button that moves products into [l] says.
String lifecycleAction(AppLocalizations l10n, ProductLifecycle l) => switch (l) {
      ProductLifecycle.active => l10n.lifecycleToActive,
      ProductLifecycle.dormant => l10n.lifecycleToDormant,
      ProductLifecycle.discontinued => l10n.lifecycleToDiscontinued,
      ProductLifecycle.archived => l10n.lifecycleToArchived,
    };

StatusTone lifecycleTone(ProductLifecycle l) => switch (l) {
      ProductLifecycle.active => StatusTone.success,
      ProductLifecycle.dormant => StatusTone.neutral,
      ProductLifecycle.discontinued => StatusTone.warning,
      ProductLifecycle.archived => StatusTone.danger,
    };

IconData lifecycleIcon(ProductLifecycle l) => switch (l) {
      ProductLifecycle.active => Icons.check_circle_outline,
      ProductLifecycle.dormant => Icons.bedtime_outlined,
      ProductLifecycle.discontinued => Icons.do_not_disturb_on_outlined,
      ProductLifecycle.archived => Icons.archive_outlined,
    };

class LifecyclePill extends StatelessWidget {
  const LifecyclePill({super.key, required this.lifecycle});

  final ProductLifecycle lifecycle;

  @override
  Widget build(BuildContext context) => StatusPill(
        tone: lifecycleTone(lifecycle),
        label: lifecycleLabel(AppLocalizations.of(context), lifecycle),
        dense: true,
      );
}

/// A product's stock on one line: on hand, reserved and what is left to
/// promise, or that there is none.
class StockLine extends StatelessWidget {
  const StockLine({super.key, required this.stock, this.style});

  final ProductStock stock;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (stock.isEmpty) {
      return Text(l10n.stockNone,
          style: (style ?? theme.textTheme.bodySmall)?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    final text = stock.reserved > 0
        ? l10n.stockLineReserved(stock.onHand, stock.reserved, stock.available)
        : l10n.stockLine(stock.onHand);
    final where = stock.warehouses.length > 1
        ? '  (${stock.warehouses.map((w) => '${w.name} ${w.onHand}').join(' / ')})'
        : stock.warehouses.length == 1
            ? '  (${stock.warehouses.single.name})'
            : '';
    return Text('$text$where',
        style: (style ?? theme.textTheme.bodySmall)?.copyWith(fontWeight: FontWeight.w600));
  }
}

String _yen(double v) => '¥${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';

/// A product's suppliers on one line: how many, then each with its unit
/// price, cheapest first, the first few by name (0123).
class SupplierLine extends StatelessWidget {
  const SupplierLine({super.key, required this.suppliers, this.max = 3});

  final List<ProductSupplierRef> suppliers;
  final int max;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final shown = suppliers.take(max).map((s) => s.unitPrice == null ? s.name : '${s.name} ${_yen(s.unitPrice!)}');
    final more = suppliers.length > max ? ' ${l10n.supMore(suppliers.length - max)}' : '';
    return Text(
      '${l10n.supCount(suppliers.length)}: ${shown.join(' / ')}$more',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// Every supplier of a product with its terms, cheapest first, the cheapest
/// marked (0123).
class SupplierTable extends StatelessWidget {
  const SupplierTable({super.key, required this.suppliers});

  final List<ProductSupplierRef> suppliers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final cheapest = ([for (final s in suppliers) if (s.unitPrice != null) s]
          ..sort((a, b) => a.unitPrice!.compareTo(b.unitPrice!)))
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in suppliers)
          Container(
            key: ValueKey('pd-supplier-${s.id}'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(s.name, style: theme.textTheme.titleSmall)),
                        if (identical(s, cheapest) && suppliers.where((x) => x.unitPrice != null).length > 1) ...[
                          const SizedBox(width: 6),
                          StatusPill(tone: StatusTone.success, label: l10n.supCheapest, dense: true),
                        ],
                        if (s.isPrimary) ...[
                          const SizedBox(width: 6),
                          StatusPill(tone: StatusTone.info, label: l10n.supPrimary, dense: true),
                        ],
                      ]),
                      if (s.theirName != null || s.theirCode != null)
                        Text(
                          [
                            if (s.theirName != null) l10n.supTheirName(s.theirName!),
                            if (s.theirCode != null) l10n.supTheirCode(s.theirCode!),
                          ].join('　'),
                          style: muted,
                        ),
                      if (s.updatedAt != null)
                        Text(l10n.supUpdated(
                                '${s.updatedAt!.year}-${s.updatedAt!.month.toString().padLeft(2, '0')}-${s.updatedAt!.day.toString().padLeft(2, '0')}'),
                            style: muted),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(s.unitPrice == null ? l10n.supNoPrice : _yen(s.unitPrice!),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (s.listPrice != null || s.discountRate != null)
                      Text(
                        [
                          if (s.listPrice != null) l10n.quoteListPrice(_yen(s.listPrice!)),
                          if (s.discountRate != null)
                            l10n.quoteRate('${(s.discountRate! * 100).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%'),
                        ].join('　'),
                        style: muted,
                      ),
                    if (s.orderLot != null) Text(l10n.quoteCase('${s.orderLot}'), style: muted),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
