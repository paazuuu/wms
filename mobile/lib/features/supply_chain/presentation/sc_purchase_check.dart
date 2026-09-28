import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../partners/application/trading_partner_providers.dart';
import '../../product/application/product_providers.dart';
import '../../purchasing/domain/purchase_order.dart';
import '../application/supply_chain_providers.dart';
import '../domain/supply_chain.dart';
import 'sc_labels.dart';
import 'sc_simulation_screen.dart';
import 'sc_widgets.dart';

/// Before a purchase order is placed (§29–30): each priced line's landed cost
/// and margin at this price from this supplier, against today's. When the
/// margin falls below the threshold or drops sharply, the buyer sees it with
/// its causes and decides (rule 6). Returns true to go ahead.
///
/// Never blocks an order on its own account: without the permission, with a
/// supplier or product the layer does not know, or when the check itself
/// fails, the order simply goes ahead.
Future<bool> scConfirmPurchaseProfit(
  BuildContext context,
  WidgetRef ref, {
  required String supplierName,
  required int warehouseId,
  required List<PurchaseOrderLineDraft> lines,
}) async {
  if (!ref.read(scCanViewProvider)) return true;
  final priced = lines.where((l) => l.unitPrice != null && l.janCode.trim().isNotEmpty).toList();
  if (priced.isEmpty) return true;

  final partners = await ref.read(tradingPartnerRepositoryProvider).list(search: supplierName.trim());
  final name = supplierName.trim().toLowerCase();
  final partnerId = partners.when(
    success: (rows) {
      final exact = rows.where((p) => p.name.trim().toLowerCase() == name).toList();
      if (exact.isNotEmpty) return exact.first.id;
      return rows.length == 1 ? rows.first.id : null;
    },
    failure: (_) => null,
  );
  if (partnerId == null) return true;

  final checkLines = <Map<String, dynamic>>[];
  for (final l in priced) {
    final found = await ref.read(productRepositoryProvider).list(search: l.janCode.trim());
    final productId = found.when(
      success: (rows) => rows.where((p) => p.janCode == l.janCode.trim()).firstOrNull?.id,
      failure: (_) => null,
    );
    if (productId != null) {
      checkLines.add({'product_id': productId, 'partner_id': partnerId, 'unit_price': l.unitPrice, 'quantity': l.quantity});
    }
  }
  if (checkLines.isEmpty) return true;

  final r = await ref.read(supplyChainRepositoryProvider).purchaseCheck(warehouseId: warehouseId, lines: checkLines);
  final warned = r.when(success: (rows) => rows.where((x) => x.warns).toList(), failure: (_) => const <ScPurchaseCheck>[]);
  if (warned.isEmpty || !context.mounted) return true;

  final go = await showDialog<bool>(
    context: context,
    builder: (_) => _ProfitWarningDialog(lines: warned),
  );
  return go == true;
}

class _ProfitWarningDialog extends StatelessWidget {
  const _ProfitWarningDialog({required this.lines});

  final List<ScPurchaseCheck> lines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String warn(String w) => switch (w) {
          'margin_low' => l10n.scWarnMarginLow,
          'margin_drop' => l10n.scWarnMarginDrop,
          'loss' => l10n.scWarnLoss,
          _ => '',
        };
    return AlertDialog(
      key: const ValueKey('sc-profit-warning'),
      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
      title: Text(l10n.scProfitWarning),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final l in lines) ...[
                Text(l.name, style: theme.textTheme.titleSmall),
                Text(l10n.scProfitWarningBody(scPercent(l.marginBefore), scPercent(l.marginAfter))),
                Text(
                  [for (final w in l.warn) warn(w)].where((x) => x.isNotEmpty).join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
                ),
                if (l.drivers.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.scCauses, style: theme.textTheme.labelMedium),
                  ScDriversList(drivers: l.drivers, unit: true, limit: 4),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.scBackToEdit)),
        TextButton(
          onPressed: () {
            Navigator.pop(context, false);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScSimulationScreen()));
          },
          child: Text(l10n.featScSimulation),
        ),
        FilledButton(
          key: const ValueKey('sc-continue-order'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.scContinueOrder),
        ),
      ],
    );
  }
}
