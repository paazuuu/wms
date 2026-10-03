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
