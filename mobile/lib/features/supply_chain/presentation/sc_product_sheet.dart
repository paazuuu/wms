import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/supply_chain_providers.dart';
import '../domain/supply_chain.dart';
import 'sc_labels.dart';
import 'sc_supplier_comparison_screen.dart';
import 'sc_widgets.dart';

/// One product's cost and profit, from anywhere (dashboard row, product
/// detail): the waterfall of the current source, and each other option.
Future<void> showScProductSheet(BuildContext context, int productId) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, controller) => ScProductProfitView(productId: productId, controller: controller),
      ),
    );

/// The product detail's 原価・利益 section (§27), for those who may see the
/// numbers; nothing at all for everyone else.
class ScProductProfitCard extends ConsumerWidget {
  const ScProductProfitCard({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(scCanViewProvider)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: ScSection(
        key: const ValueKey('sc-product-card'),
        title: AppLocalizations.of(context).scProductCard,
        child: ScProductProfitView(productId: productId, compact: true),
      ),
    );
  }
}

class ScProductProfitView extends ConsumerWidget {
  const ScProductProfitView({super.key, required this.productId, this.controller, this.compact = false});

  final int productId;
  final ScrollController? controller;

  /// Inside another screen (product detail): no scroll view of its own.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(scProductViewProvider((productId: productId, rates: '', lot: null)));
    final body = async.when(
      loading: () => const [Padding(padding: EdgeInsets.all(AppSpacing.lg), child: LinearProgressIndicator())],
      error: (e, _) => [Text(humanizeApiErrorMessage(l10n, '$e'))],
      data: (view) {
        final p = view.product;
        if (p == null || p.options.isEmpty) {
          return [
            Text(l10n.scNoTerms, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScSupplierComparisonScreen(initialProductId: productId))),
                icon: const Icon(Icons.add),
                label: Text(l10n.scAddTerm),
              ),
            ),
          ];
        }
        return [
          if (!compact) Text(p.name, style: theme.textTheme.titleMedium),
          Text(
            [
              if (p.janCode != null) p.janCode!,
              if (p.maker != null) p.maker!,
              '${l10n.scVolume} ${scNumber(p.volume)}',
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          if (p.supplied) ...[
            Text(
              '${l10n.scChosen}: ${p.chosen.map((c) => '${c.partnerName}${c.routeName != null ? ' / ${c.routeName}' : ''}').join(', ')}',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.scWaterfall, style: theme.textTheme.labelMedium),
            ScProfitWaterfall(salesPrice: p.salesPrice, unit: p.unit, profit: p.profitPerUnit),
            const SizedBox(height: AppSpacing.md),
          ],
          for (final o in p.options) _OptionTile(option: o, chosen: p.chosen.any((c) => c.key == o.key)),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('sc-open-comparison'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScSupplierComparisonScreen(initialProductId: productId))),
              icon: const Icon(Icons.compare_arrows),
              label: Text(l10n.scOpenComparison),
            ),
          ),
        ];
      },
    );
    if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body);
    return ListView(controller: controller, padding: const EdgeInsets.all(AppSpacing.lg), children: body);
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.chosen});

  final ScOption option;
  final bool chosen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final o = option;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        dense: true,
        leading: Icon(scModeIcon(o.mode), color: o.available ? theme.colorScheme.primary : theme.colorScheme.outline),
        title: Row(
          children: [
            Flexible(child: Text('${o.partnerName} / ${o.routeName ?? l10n.scNoRoute}', overflow: TextOverflow.ellipsis)),
            if (chosen) ...[
              const SizedBox(width: AppSpacing.xs),
              StatusPill(tone: StatusTone.info, label: l10n.scCurrent, dense: true),
            ],
            if (!o.available) ...[
              const SizedBox(width: AppSpacing.xs),
              StatusPill(tone: StatusTone.neutral, label: l10n.scBlocked, dense: true),
            ],
          ],
        ),
        subtitle: Text([
          '${l10n.scLandedCost} ${scUnitMoney(o.unit.landed)}',
          l10n.scDays(scNumber(o.leadTimeDays)),
          for (final n in o.notes) scNoteLabel(l10n, n),
        ].join(' · ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(scUnitMoney(o.profitPerUnit),
                style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: AppFonts.mono, color: o.profitPerUnit < 0 ? AppColors.danger : AppColors.success)),
            Text(scPercent(o.margin), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
